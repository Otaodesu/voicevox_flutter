cmake_minimum_required(VERSION 3.10)

set(PROJECT_NAME "voicevox_flutter")
project(${PROJECT_NAME} LANGUAGES CXX)

set(PLUGIN_NAME "${PROJECT_NAME}_plugin")

add_library(${PLUGIN_NAME} SHARED
  "voicevox_flutter_plugin.cc"
)

apply_standard_settings(${PLUGIN_NAME})

target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(${PLUGIN_NAME} INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}/include")

target_link_libraries(${PLUGIN_NAME} PRIVATE flutter)

# List of shared libraries to bundle with the application
set(voicevox_flutter_bundled_libraries
  "${CMAKE_CURRENT_SOURCE_DIR}/blobs/x86_64/libvoicevox_core.so"
  "${CMAKE_CURRENT_SOURCE_DIR}/blobs/x86_64/libvoicevox_onnxruntime.so"
  "${CMAKE_CURRENT_SOURCE_DIR}/blobs/x86_64/libvoicevox_onnxruntime.so.1.17.3"
  PARENT_SCOPE
)
