cmake_minimum_required(VERSION 3.16)
project(msp VERSION 3.4.0 LANGUAGES CXX)

set(PROJECT_DESCRIPTION "Implementation of the MultiWii Serial Protocol (MSP)")

# ---------- options ----------
option(MSP_ENABLE_WARNINGS      "Enable high warning level"               ON)
option(MSP_WARNINGS_AS_ERRORS   "Treat warnings as errors"                OFF)
option(MSP_ENABLE_SANITIZERS    "Enable sanitizers in Debug (GCC/Clang)"  OFF)
option(BUILD_EXAMPLES           "Build Library with examples"             ON)
option(BUILD_TESTS              "Build Library with tests"                OFF)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# ---------- module path (try parent/superproject first) ----------
# Коли збираємося як сабпроєкт через FetchContent/add_subdirectory,
# ${CMAKE_SOURCE_DIR} зазвичай вказує на корінь суперпроєкту.
foreach(_p
  "${CMAKE_SOURCE_DIR}/cmake/modules"
  "${PROJECT_SOURCE_DIR}/cmake/modules"
  "${CMAKE_CURRENT_LIST_DIR}/cmake/modules"
)
  if (EXISTS "${_p}")
    list(PREPEND CMAKE_MODULE_PATH "${_p}")
  endif()
endforeach()

# ---------- threads ----------
find_package(Threads REQUIRED)

# ---------- find/fetch ASIO (header-only) ----------
# 1) Спробувати модуль
find_package(ASIO QUIET MODULE)

# 2) Якщо модуль не спрацював, підключити його явно (щоб гарантовано відпрацював fetch)
if (NOT ASIO_FOUND)
  if (EXISTS "${CMAKE_SOURCE_DIR}/cmake/modules/FindASIO.cmake")
    include("${CMAKE_SOURCE_DIR}/cmake/modules/FindASIO.cmake")
  elseif (EXISTS "${PROJECT_SOURCE_DIR}/cmake/modules/FindASIO.cmake")
    include("${PROJECT_SOURCE_DIR}/cmake/modules/FindASIO.cmake")
  elseif (EXISTS "${CMAKE_CURRENT_LIST_DIR}/cmake/modules/FindASIO.cmake")
    include("${CMAKE_CURRENT_LIST_DIR}/cmake/modules/FindASIO.cmake")
  endif()
endif()

# 3) Остання спроба: локальний fetch без модуля
if (NOT ASIO_FOUND)
  include(FetchContent)
  message(STATUS "ASIO not found via module — fetching locally...")
  FetchContent_Declare(
    _asio_fallback
    GIT_REPOSITORY https://github.com/chriskohlhoff/asio.git
    GIT_TAG        asio-1-30-2
    GIT_SHALLOW    TRUE
    GIT_PROGRESS   TRUE
  )
  FetchContent_Populate(_asio_fallback)
  set(_ASIO_INC "${_asio_fallback_SOURCE_DIR}/asio/include")
  if (EXISTS "${_ASIO_INC}/asio.hpp")
    add_library(ASIO::ASIO INTERFACE IMPORTED GLOBAL)
    set_target_properties(ASIO::ASIO PROPERTIES
      INTERFACE_INCLUDE_DIRECTORIES "${_ASIO_INC}"
      INTERFACE_COMPILE_DEFINITIONS "ASIO_STANDALONE"
    )
    target_link_libraries(ASIO::ASIO INTERFACE Threads::Threads)
    set(ASIO_FOUND TRUE)
    message(STATUS "✅ ASIO include (fallback): ${_ASIO_INC}")
  endif()
endif()

if (NOT ASIO_FOUND)
  message(FATAL_ERROR "ASIO not found and fetch failed. Set ASIO_ROOT/ASIO_DIR or ensure cmake/modules/FindASIO.cmake is available.")
endif()

# ---------- targets ----------
set(MSP_SOURCE_DIR src)
set(MSP_INCLUDE_DIR inc/msp)

add_library(mspclient
  ${MSP_SOURCE_DIR}/Client.cpp
  ${MSP_SOURCE_DIR}/PeriodicTimer.cpp
)
target_include_directories(mspclient PUBLIC ${MSP_INCLUDE_DIR})
target_link_libraries(mspclient PUBLIC ASIO::ASIO Threads::Threads)
target_compile_definitions(mspclient PUBLIC
  ASIO_STANDALONE
  ASIO_HAS_STD_ADDRESSOF
  ASIO_HAS_STD_ARRAY
  ASIO_HAS_CSTDINT
  ASIO_HAS_STD_SHARED_PTR
  ASIO_HAS_STD_TYPE_TRAITS
)

add_library(msp_fcu
  ${MSP_SOURCE_DIR}/FlightController.cpp
)
target_link_libraries(msp_fcu PUBLIC mspclient)
target_include_directories(msp_fcu PUBLIC ${MSP_INCLUDE_DIR})

# ---------- warnings ----------
if (MSP_ENABLE_WARNINGS)
  if (MSVC)
    target_compile_options(mspclient PRIVATE /W4)
    target_compile_options(msp_fcu    PRIVATE /W4)
    if (MSP_WARNINGS_AS_ERRORS)
      target_compile_options(mspclient PRIVATE /WX)
      target_compile_options(msp_fcu    PRIVATE /WX)
    endif()
    # Windows SDK target (10 = 0x0A00). Підійде і 0x0601 (Win7), але 10 безпечніше.
    target_compile_definitions(mspclient PRIVATE _WIN32_WINNT=0x0A00)
    target_compile_definitions(msp_fcu    PRIVATE _WIN32_WINNT=0x0A00)
  else()
    target_compile_options(mspclient PRIVATE -Wall -Wextra -Wpedantic)
    target_compile_options(msp_fcu    PRIVATE -Wall -Wextra -Wpedantic)
    if (MSP_WARNINGS_AS_ERRORS)
      target_compile_options(mspclient PRIVATE -Werror)
      target_compile_options(msp_fcu    PRIVATE -Werror)
    endif()
  endif()
endif()

# ---------- sanitizers (GCC/Clang only, Debug) ----------
if (MSP_ENABLE_SANITIZERS AND CMAKE_BUILD_TYPE MATCHES "Debug")
  if (CMAKE_CXX_COMPILER_ID MATCHES "Clang|GNU")
    set(_asan_flags "-fsanitize=address,undefined")
    target_compile_options(mspclient PRIVATE ${_asan_flags} -fno-omit-frame-pointer)
    target_link_options   (mspclient PRIVATE ${_asan_flags})
    target_compile_options(msp_fcu    PRIVATE ${_asan_flags} -fno-omit-frame-pointer)
    target_link_options   (msp_fcu    PRIVATE ${_asan_flags})
    if (NOT APPLE)
      target_compile_options(mspclient PRIVATE -fsanitize=leak)
      target_link_options   (mspclient PRIVATE -fsanitize=leak)
      target_compile_options(msp_fcu    PRIVATE -fsanitize=leak)
      target_link_options   (msp_fcu    PRIVATE -fsanitize=leak)
    endif()
  endif()
endif()

# ---------- examples ----------
if (BUILD_EXAMPLES)
  add_executable(fcu_test examples/fcu_test.cpp)
  target_link_libraries(fcu_test PRIVATE msp_fcu)

  add_executable(fcu_motors examples/fcu_motor_test.cpp)
  target_link_libraries(fcu_motors PRIVATE msp_fcu)

  add_executable(fcu_custom_type examples/fcu_custom_type.cpp)
  target_link_libraries(fcu_custom_type PRIVATE msp_fcu)

  add_executable(client_async_test examples/client_async_test.cpp)
  target_link_libraries(client_async_test PRIVATE mspclient)

  add_executable(client_read_test examples/client_read_test.cpp)
  target_link_libraries(client_read_test PRIVATE mspclient)
endif()

# ---------- install ----------
install(TARGETS msp_fcu mspclient
  EXPORT mspTargets
  LIBRARY DESTINATION lib
  ARCHIVE DESTINATION lib
)
install(DIRECTORY ${MSP_INCLUDE_DIR} DESTINATION include FILES_MATCHING PATTERN "*.hpp")

# pkg-config (як було)
set(PKG_CONFIG_LIBDIR       "\${prefix}/lib")
set(PKG_CONFIG_INCLUDEDIR   "\${prefix}/include/")
set(PKG_CONFIG_LIBS         "-L\${libdir} -lmsp_fcu -lmspclient")
set(PKG_CONFIG_CFLAGS       "-I\${includedir}")
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/pkg-config.pc.cmake
               ${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}.pc
               @ONLY)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}.pc
        DESTINATION lib/pkgconfig)

# ---------- tests ----------
if (BUILD_TESTS)
  enable_testing()
  # ... (залиш без змін)
endif()
