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

# якщо FindASIO.cmake лежить у корені твого суперпроєкту: <root>/cmake/modules
# CMAKE_SOURCE_DIR тут — корінь суперпроєкту, коли msp тягнемо через add_subdirectory/FetchContent
list(PREPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake/modules")

# ---------- find ASIO (header-only) ----------
# Prefer a config package if available
find_package(ASIO QUIET)
if (NOT ASIO_FOUND)
  # Fallback: header-only include dir
  find_path(ASIO_INCLUDE_DIR
    NAMES asio.hpp
    HINTS ${ASIO_ROOT} ${ASIO_DIR}
    PATH_SUFFIXES include asio
  )
  if (NOT ASIO_INCLUDE_DIR)
    message(FATAL_ERROR "ASIO not found. Set ASIO_ROOT/ASIO_DIR or install ASIO.")
  endif()
  add_library(ASIO::ASIO INTERFACE)
  target_include_directories(ASIO::ASIO INTERFACE ${ASIO_INCLUDE_DIR})
endif()

find_package(Threads REQUIRED)

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

# pkg-config (optional, як було)
set(PKG_CONFIG_LIBDIR       "\${prefix}/lib")
set(PKG_CONFIG_INCLUDEDIR   "\${prefix}/include/")
set(PKG_CONFIG_LIBS         "-L\${libdir} -lmsp_fcu -lmspclient")
set(PKG_CONFIG_CFLAGS       "-I\${includedir}")
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/pkg-config.pc.cmake
               ${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}.pc
               @ONLY)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}.pc
        DESTINATION lib/pkgconfig)

# ---------- tests (залишив як є, але без глобальних флагів) ----------
if (BUILD_TESTS)
  enable_testing()
  # ... (твій існуючий блок для gtest; бажано також без глобальних флагів)
endif()
