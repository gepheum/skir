cmake_minimum_required(VERSION 3.20)
project(skir-client CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# ============================================================================
# Dependencies - Use existing targets if available, otherwise fetch them
# ============================================================================

# Abseil - use existing installation if available, otherwise fetch
include(FetchContent)

if(NOT TARGET absl::base)
  FetchContent_Declare(
    absl
    GIT_REPOSITORY https://github.com/abseil/abseil-cpp.git
    GIT_TAG 20260107.0
  )
  set(ABSL_PROPAGATE_CXX_STD ON)
  set(ABSL_USE_EXTERNAL_GOOGLETEST ON CACHE BOOL "" FORCE)
  set(ABSL_FIND_GOOGLETEST OFF CACHE BOOL "" FORCE)
  FetchContent_MakeAvailable(absl)
endif()

# GoogleTest - optional, only needed for testing library
if(NOT DEFINED SKIR_ENABLE_TESTING)
  # Default: enable testing if GTest is available
  if(TARGET GTest::gtest)
    set(SKIR_ENABLE_TESTING ON)
  else()
    find_package(GTest QUIET)
    if(GTest_FOUND)
      set(SKIR_ENABLE_TESTING ON)
    else()
      # Try to fetch GoogleTest
      include(FetchContent)
      FetchContent_Declare(
        googletest
        GIT_REPOSITORY https://github.com/google/googletest.git
        GIT_TAG v1.15.2
      )
      set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
      FetchContent_MakeAvailable(googletest)
      if(TARGET GTest::gtest)
        set(SKIR_ENABLE_TESTING ON)
      else()
        set(SKIR_ENABLE_TESTING OFF)
      endif()
    endif()
  endif()
endif()

message(STATUS "Skir testing library: ${SKIR_ENABLE_TESTING}")

# ============================================================================
# Main skir library
# ============================================================================

add_library(skir
  skir.cc
  skir.h
)

target_include_directories(skir PUBLIC 
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
  $<INSTALL_INTERFACE:include>
)

target_link_libraries(skir PUBLIC
  absl::base
  absl::flat_hash_map
  absl::hash
  absl::check
  absl::die_if_null
  absl::status
  absl::statusor
  absl::strings
  absl::time
  absl::optional
  absl::variant
)

# ============================================================================
# Testing library (interface library with header-only implementation)
# Only built if GTest is available
# ============================================================================

if(SKIR_ENABLE_TESTING)
  add_library(skir_testing INTERFACE)

  target_sources(skir_testing INTERFACE
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/skir.testing.h>
    $<INSTALL_INTERFACE:include/skir.testing.h>
  )

  target_include_directories(skir_testing INTERFACE
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<INSTALL_INTERFACE:include>
  )

  target_link_libraries(skir_testing INTERFACE
    skir
    absl::base
    absl::die_if_null
    GTest::gtest
    GTest::gmock
  )

  message(STATUS "Skir testing library target created")
else()
  message(STATUS "Skir testing library disabled (GTest not available)")
endif()
