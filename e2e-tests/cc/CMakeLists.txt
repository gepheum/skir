cmake_minimum_required(VERSION 3.20)
project(skir-e2e-test CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# ============================================================================
# Dependencies
# ============================================================================

include(FetchContent)

# Find or fetch GoogleTest first (before Abseil)
if(NOT TARGET gtest)
  FetchContent_Declare(
    googletest
    GIT_REPOSITORY https://github.com/google/googletest.git
    GIT_TAG v1.15.2
  )
  set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
  FetchContent_MakeAvailable(googletest)
  
  # Create GTest:: aliases if they don't exist
  if(NOT TARGET GTest::gtest)
    add_library(GTest::gtest ALIAS gtest)
    add_library(GTest::gtest_main ALIAS gtest_main)
    add_library(GTest::gmock ALIAS gmock)
    add_library(GTest::gmock_main ALIAS gmock_main)
  endif()
endif()

# Find or fetch Abseil
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

# Find or fetch cpp-httplib
if(NOT TARGET httplib::httplib)
  include(FetchContent)
  
  FetchContent_Declare(
    httplib
    GIT_REPOSITORY https://github.com/yhirose/cpp-httplib.git
    GIT_TAG v0.18.4
  )
  FetchContent_MakeAvailable(httplib)
endif()

# Enable testing
enable_testing()
include(GoogleTest)

# ============================================================================
# Libraries
# ============================================================================

# Reserializer testing library
add_library(reserializer_testing INTERFACE)
target_sources(reserializer_testing INTERFACE
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/reserializer.testing.h>
)
target_include_directories(reserializer_testing INTERFACE
  ${CMAKE_CURRENT_SOURCE_DIR}
)
target_link_libraries(reserializer_testing INTERFACE
  absl::flat_hash_set
  absl::status
  absl::statusor
  absl::strings
  absl::optional
)

# Main skir library (from client-libraries/cc)
set(SKIR_CLIENT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../client-libraries/cc")
add_library(skir
  ${SKIR_CLIENT_DIR}/skir.cc
  ${SKIR_CLIENT_DIR}/skir.h
)
target_include_directories(skir PUBLIC
  ${SKIR_CLIENT_DIR}
  ${CMAKE_CURRENT_SOURCE_DIR}
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

# Skir testing library
add_library(skir_testing INTERFACE)
target_sources(skir_testing INTERFACE
  $<BUILD_INTERFACE:${SKIR_CLIENT_DIR}/skir.testing.h>
)
target_include_directories(skir_testing INTERFACE
  ${SKIR_CLIENT_DIR}
  ${CMAKE_CURRENT_SOURCE_DIR}
)
target_link_libraries(skir_testing INTERFACE
  skir
  absl::base
  absl::die_if_null
  GTest::gtest
)

# Skirout library (generated code)
file(GLOB_RECURSE SKIROUT_SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/skirout/*.cc")
file(GLOB_RECURSE SKIROUT_HEADERS "${CMAKE_CURRENT_SOURCE_DIR}/skirout/*.h")

add_library(skirout
  ${SKIROUT_SOURCES}
)
target_include_directories(skirout PUBLIC
  ${CMAKE_CURRENT_SOURCE_DIR}
)
target_link_libraries(skirout PUBLIC
  skir
)

# ============================================================================
# Tests
# ============================================================================

# skir.test
add_executable(skir_test skir.test.cc)
target_link_libraries(skir_test PRIVATE
  skir
  reserializer_testing
  absl::flat_hash_set
  absl::status
  absl::statusor
  absl::strings
  GTest::gtest
  GTest::gtest_main
  GTest::gmock
)
gtest_discover_tests(skir_test)

# skir_service.test
add_executable(skir_service_test skir_service.test.cc)
target_link_libraries(skir_service_test PRIVATE
  skir
  skir_testing
  skirout
  absl::flat_hash_map
  absl::statusor
  absl::strings
  httplib::httplib
  GTest::gtest
  GTest::gtest_main
  GTest::gmock
)
gtest_discover_tests(skir_service_test)

# skirout.test
add_executable(skirout_test skirout.test.cc)
target_link_libraries(skirout_test PRIVATE
  reserializer_testing
  skir_testing
  skir
  skirout
  absl::flat_hash_set
  absl::status
  absl::statusor
  absl::strings
  GTest::gtest
  GTest::gtest_main
  GTest::gmock
)
gtest_discover_tests(skirout_test)

# skir_goldens.test
add_executable(skir_goldens_test skir_goldens.test.cc)
target_link_libraries(skir_goldens_test PRIVATE
  skir
  skirout
  absl::status
  absl::statusor
  absl::strings
  GTest::gtest
  GTest::gtest_main
)
gtest_discover_tests(skir_goldens_test)
