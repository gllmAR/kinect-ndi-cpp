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

# Add NDI SDK include directory.
include_directories("${NDI_SDK_DIR}/include")

# If an NDI SDK lib directory exists, add it to the linker search path.
if(EXISTS "${NDI_SDK_DIR}/lib")
  link_directories("${NDI_SDK_DIR}/lib")
endif()

# On macOS, ensure pkg-config can find Homebrew's pkgconfig files.
if(APPLE)
  if(NOT DEFINED ENV{PKG_CONFIG_PATH})
    set(ENV{PKG_CONFIG_PATH} "/opt/homebrew/lib/pkgconfig:/usr/local/lib/pkgconfig")
  else()
    string(FIND "$ENV{PKG_CONFIG_PATH}" "/opt/homebrew/lib/pkgconfig" _found)
    if(${_found} EQUAL -1)
      set(ENV{PKG_CONFIG_PATH} "$ENV{PKG_CONFIG_PATH}:/opt/homebrew/lib/pkgconfig")
    endif()
    string(FIND "$ENV{PKG_CONFIG_PATH}" "/usr/local/lib/pkgconfig" _found2)
    if(${_found2} EQUAL -1)
      set(ENV{PKG_CONFIG_PATH} "$ENV{PKG_CONFIG_PATH}:/usr/local/lib/pkgconfig")
    endif()
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

# On macOS, print the include directories and check for libfreenect.h.
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

# Set the NDI library path based on platform.
if(APPLE)
  set(NDI_LIB_PATH "${NDI_SDK_DIR}/lib/macOS/libndi.dylib")
else()
  set(NDI_LIB_PATH "${NDI_SDK_DIR}/lib/libndi.so")
endif()

add_executable(kinect_ndi_cross_platform kinect_ndi_cross_platform.cpp)

# Link explicitly with the correct NDI library.
target_link_libraries(kinect_ndi_cross_platform ${FREENECT_LIBRARIES} "${NDI_LIB_PATH}")
