# FindASIO.cmake — provides ASIO::ASIO (standalone, header-only)
include_guard(GLOBAL)

# Already provided?
if (TARGET ASIO::ASIO)
  set(ASIO_FOUND TRUE)
  return()
endif()

find_package(Threads REQUIRED)

set(ASIO_FOUND FALSE)

# -- candidate paths --
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

if (DEFINED ASIO_ROOT)
  list(PREPEND _ASIO_SEARCH_PATHS "${ASIO_ROOT}")
endif()

# 1) Try to find headers without fetching
find_path(ASIO_INCLUDE_DIR
  NAMES asio.hpp
  PATH_SUFFIXES include asio
  PATHS ${_ASIO_SEARCH_PATHS}
  NO_DEFAULT_PATH
)

if (NOT ASIO_INCLUDE_DIR)
  find_path(ASIO_INCLUDE_DIR
    NAMES asio.hpp
    PATH_SUFFIXES include asio
  )
endif()

# 2) If still missing — fetch the repo (header-only)
if (NOT ASIO_INCLUDE_DIR)
  include(FetchContent)

  # chriskohlhoff/asio structure: <src>/asio/include/asio.hpp
  FetchContent_Declare(
    _asio_fetch
    GIT_REPOSITORY https://github.com/chriskohlhoff/asio.git
    GIT_TAG 84b558d124be15b280538d34c47bbdbd4cef6fd8
    GIT_PROGRESS TRUE
  )
  FetchContent_Populate(_asio_fetch)

  # Expected include dir:
  set(ASIO_INCLUDE_DIR "${_asio_fetch_SOURCE_DIR}/asio/include")

  if (EXISTS "${ASIO_INCLUDE_DIR}/asio.hpp")
    # expose the root so subprojects can cache it
    set(ASIO_ROOT "${_asio_fetch_SOURCE_DIR}/asio" CACHE PATH "ASIO root" FORCE)
    message(STATUS "⬇️  Fetched ASIO into: ${ASIO_ROOT}")
  else()
    unset(ASIO_INCLUDE_DIR)
  endif()
endif()

# 3) Create interface target if found
if (ASIO_INCLUDE_DIR)
  add_library(ASIO::ASIO INTERFACE IMPORTED GLOBAL)
  set_target_properties(ASIO::ASIO PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "${ASIO_INCLUDE_DIR}"
    INTERFACE_COMPILE_DEFINITIONS "ASIO_STANDALONE"
  )
  target_link_libraries(ASIO::ASIO INTERFACE Threads::Threads)
  set(ASIO_FOUND TRUE)
  message(STATUS "✅ ASIO include: ${ASIO_INCLUDE_DIR}")
else()
  set(ASIO_FOUND FALSE)
  if (ASIO_FIND_REQUIRED)
    message(FATAL_ERROR "❌ ASIO headers not found and fetch failed. Set ASIO_ROOT or provide via package manager.")
  else()
    message(WARNING "⚠️  ASIO headers not found.")
  endif()
endif()
