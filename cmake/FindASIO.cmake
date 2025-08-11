# cmake/modules/FindASIO.cmake
# Provides ASIO::ASIO (standalone header-only)

include_guard(GLOBAL)
set(ASIO_FOUND FALSE)

if (TARGET ASIO::ASIO)
  set(ASIO_FOUND TRUE)
  return()
endif()

find_package(Threads REQUIRED)

# Пошук можливих шляхів
set(_ASIO_SEARCH_PATHS
  "${CMAKE_SOURCE_DIR}/third_party/asio"
  "${CMAKE_SOURCE_DIR}/external/asio"
  "${CMAKE_SOURCE_DIR}/vendor/asio"
  "${CMAKE_SOURCE_DIR}/../asio"
  "$ENV{ASIO_ROOT}"
  "$ENV{ASIO_DIR}"
  "$ENV{VCPKG_ROOT}/installed/${VCPKG_TARGET_TRIPLET}/include"
  "/usr/include"
  "C:/Program Files (x86)/asio"
)

# Якщо суперпроєкт завантажив asio через FetchContent —
# ти встановиш ASIO_ROOT у кеші (див. крок 2)
if (DEFINED ASIO_ROOT)
  list(PREPEND _ASIO_SEARCH_PATHS "${ASIO_ROOT}")
endif()

# Спочатку шукаємо заголовок у вказаних шляхах без дефолтів
find_path(ASIO_INCLUDE_DIR
  NAMES asio.hpp
  PATH_SUFFIXES asio include
  PATHS ${_ASIO_SEARCH_PATHS}
  NO_DEFAULT_PATH
)

# Фолбек — зі стандартними шляхами
if (NOT ASIO_INCLUDE_DIR)
  find_path(ASIO_INCLUDE_DIR
    NAMES asio.hpp
    PATH_SUFFIXES asio include
  )
endif()

if (ASIO_INCLUDE_DIR)
  add_library(ASIO::ASIO INTERFACE IMPORTED GLOBAL)
  set_target_properties(ASIO::ASIO PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "${ASIO_INCLUDE_DIR}"
    INTERFACE_COMPILE_DEFINITIONS "ASIO_STANDALONE"
  )
  target_link_libraries(ASIO::ASIO INTERFACE Threads::Threads)
  set(ASIO_FOUND TRUE)
  message(STATUS "✅ Found ASIO in ${ASIO_INCLUDE_DIR}")
else()
  if (ASIO_FIND_REQUIRED)
    message(FATAL_ERROR "❌ ASIO headers could not be found. Set ASIO_ROOT or provide asio via vcpkg/FetchContent.")
  else()
    message(WARNING "⚠️ ASIO headers not found.")
  endif()
endif()
