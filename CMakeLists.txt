cmake_minimum_required(VERSION 3.10)
project(KinectNDI)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Set NDI SDK directory from command-line or use default.
if(NOT DEFINED NDI_SDK_DIR)
  if(APPLE)
    set(NDI_SDK_DIR "/Library/NDI SDK for Apple")
  elseif(UNIX)
    set(NDI_SDK_DIR "/opt/ndi_sdk")
  endif()
endif()

# On Linux, if a local copy of the NDI SDK exists in the source directory, use it.
if(UNIX AND NOT APPLE)
  if(EXISTS "${CMAKE_SOURCE_DIR}/NDI SDK for Linux/include/Processing.NDI.Lib.h")
    message(STATUS "Found local NDI SDK for Linux in the project directory.")
    set(NDI_SDK_DIR "${CMAKE_SOURCE_DIR}/NDI SDK for Linux")
  endif()
endif()

message(STATUS "Using NDI SDK directory: ${NDI_SDK_DIR}")

# Add NDI SDK include directory.
include_directories("${NDI_SDK_DIR}/include")

# Determine the NDI library path.
if(APPLE)
  set(NDI_LIB_PATH "${NDI_SDK_DIR}/lib/macOS/libndi.dylib")
  link_directories("${NDI_SDK_DIR}/lib/macOS")
else()
  # On Linux, check for libndi.so in common locations.
  if(EXISTS "${NDI_SDK_DIR}/lib/libndi.so")
    set(NDI_LIB_PATH "${NDI_SDK_DIR}/lib/libndi.so")
    link_directories("${NDI_SDK_DIR}/lib")
  elseif(EXISTS "${NDI_SDK_DIR}/lib/x86_64-linux-gnu/libndi.so")
    set(NDI_LIB_PATH "${NDI_SDK_DIR}/lib/x86_64-linux-gnu/libndi.so")
    link_directories("${NDI_SDK_DIR}/lib/x86_64-linux-gnu")
  else()
    message(FATAL_ERROR "NDI library libndi.so not found in ${NDI_SDK_DIR}/lib or ${NDI_SDK_DIR}/lib/x86_64-linux-gnu.")
  endif()
endif()

find_package(PkgConfig REQUIRED)
pkg_check_modules(FREENECT REQUIRED libfreenect)

# Use the include directories provided by pkg-config.
include_directories(${FREENECT_INCLUDE_DIRS})

# Add the library directories provided by pkg-config.
if(DEFINED FREENECT_LIBRARY_DIRS)
  link_directories(${FREENECT_LIBRARY_DIRS})
endif()

if(APPLE)
  message(STATUS "FREENECT_INCLUDE_DIRS: ${FREENECT_INCLUDE_DIRS}")
  set(found_freenect_h FALSE)
  foreach(dir ${FREENECT_INCLUDE_DIRS})
    if(EXISTS "${dir}/libfreenect.h")
      set(found_freenect_h TRUE)
      message(STATUS "Found libfreenect.h in ${dir}")
    endif()
  endforeach()
  if(NOT found_freenect_h)
    message(WARNING "libfreenect.h not found in FREENECT_INCLUDE_DIRS. Please verify your libfreenect installation.")
  endif()
endif()

add_executable(kinect_ndi_cross_platform kinect_ndi_cross_platform.cpp)
target_link_libraries(kinect_ndi_cross_platform ${FREENECT_LIBRARIES} "${NDI_LIB_PATH}")
