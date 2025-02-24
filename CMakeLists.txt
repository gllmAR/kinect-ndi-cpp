cmake_minimum_required(VERSION 3.10)
project(KinectNDI)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

#-----------------------------------------------------------------------------
# 1) Set NDI_SDK_DIR from command line or default
#-----------------------------------------------------------------------------
if(NOT DEFINED NDI_SDK_DIR)
  if(APPLE)
    set(NDI_SDK_DIR "/Library/NDI SDK for Apple")
  elseif(UNIX)
    set(NDI_SDK_DIR "/opt/ndi_sdk")
  endif()
endif()

#-----------------------------------------------------------------------------
# 2) Check if local copy of the NDI SDK for Linux exists in the project dir
#    (this is optional if you prefer to store the SDK in the repo).
#-----------------------------------------------------------------------------
if(UNIX AND NOT APPLE)
  # If there's a local "NDI SDK for Linux/include/Processing.NDI.Lib.h" ...
  if(EXISTS "${CMAKE_SOURCE_DIR}/NDI SDK for Linux/include/Processing.NDI.Lib.h")
    message(STATUS "Found local NDI SDK for Linux in the project directory.")
    set(NDI_SDK_DIR "${CMAKE_SOURCE_DIR}/NDI SDK for Linux")
  endif()
endif()

message(STATUS "Using NDI SDK directory: ${NDI_SDK_DIR}")

#-----------------------------------------------------------------------------
# 3) Detect architecture on Linux and set up NDI library paths
#    On Raspberry Pi, we want to pick the ARM subfolder:
#       - armv7l  -> "arm-rpi4-linux-gnueabihf" (32-bit Pi 4 OS)
#       - aarch64 -> "aarch64-rpi4-linux-gnueabi" (64-bit Pi 4 OS)
#    Adjust to match your Pi model / OS.
#-----------------------------------------------------------------------------
if(APPLE)
  # ------------------------------------------------
  # Apple / macOS case
  # ------------------------------------------------
  set(NDI_LIB_PATH "${NDI_SDK_DIR}/lib/macOS/libndi.dylib")
  link_directories("${NDI_SDK_DIR}/lib/macOS")

elseif(UNIX)
  # ------------------------------------------------
  # Linux case (including Raspberry Pi)
  # ------------------------------------------------

  # Detect CPU architecture
  if(CMAKE_SYSTEM_PROCESSOR STREQUAL "aarch64")
    message(STATUS "Detected aarch64 (64-bit ARM)")
    set(NDI_ARCH "aarch64-rpi4-linux-gnueabi")
  elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "armv7l")
    message(STATUS "Detected armv7l (32-bit ARM)")
    set(NDI_ARCH "arm-rpi4-linux-gnueabihf")
    # or "arm-rpi3-linux-gnueabihf" if you’re on a Pi 3
    # set(NDI_ARCH "arm-rpi3-linux-gnueabihf")
  elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "x86_64")
    message(STATUS "Detected x86_64")
    set(NDI_ARCH "x86_64-linux-gnu")
  else()
    message(WARNING "Unknown CPU architecture: ${CMAKE_SYSTEM_PROCESSOR}, defaulting to x86_64 build of NDI.")
    set(NDI_ARCH "x86_64-linux-gnu")
  endif()

  # NDI puts the library in "bin/<arch>" or "lib/<arch>" depending on SDK version
  # Adjust if your SDK uses a different layout. In the latest Linux ARM SDK,
  # you typically find "bin/<arch>/libndi.so". We'll try that layout first:
  set(NDI_LIB_DIR "${NDI_SDK_DIR}/bin/${NDI_ARCH}")
  set(NDI_LIB_PATH "${NDI_LIB_DIR}/libndi.so")

  if(EXISTS "${NDI_LIB_PATH}")
    message(STATUS "Found NDI library for arch ${NDI_ARCH} in: ${NDI_LIB_PATH}")
    link_directories("${NDI_LIB_DIR}")
  else()
    # If not found in bin/<arch>, check lib/<arch>
    set(NDI_LIB_DIR "${NDI_SDK_DIR}/lib/${NDI_ARCH}")
    set(NDI_LIB_PATH "${NDI_LIB_DIR}/libndi.so")
    if(EXISTS "${NDI_LIB_PATH}")
      message(STATUS "Found NDI library for arch ${NDI_ARCH} in: ${NDI_LIB_PATH}")
      link_directories("${NDI_LIB_DIR}")
    else()
      message(FATAL_ERROR 
        "NDI library libndi.so not found for ${NDI_ARCH} in:\n"
        "  ${NDI_SDK_DIR}/bin/${NDI_ARCH}\n"
        "  or\n"
        "  ${NDI_SDK_DIR}/lib/${NDI_ARCH}\n"
        "Please ensure you have the correct ARM/x86_64 subfolder."
      )
    endif()
  endif()

else()
  message(FATAL_ERROR "Unsupported platform (not Apple, not Unix).")
endif()

#-----------------------------------------------------------------------------
# 4) Add the NDI SDK include directory
#    Often the NDI SDK has a single top-level include folder:
#-----------------------------------------------------------------------------
include_directories("${NDI_SDK_DIR}/include")

#-----------------------------------------------------------------------------
# 5) Locate libfreenect (Kinect drivers) via pkg-config
#-----------------------------------------------------------------------------
find_package(PkgConfig REQUIRED)
pkg_check_modules(FREENECT REQUIRED libfreenect)

# Use the include directories provided by pkg-config.
include_directories(${FREENECT_INCLUDE_DIRS})

# Add the library directories provided by pkg-config.
if(DEFINED FREENECT_LIBRARY_DIRS)
  link_directories(${FREENECT_LIBRARY_DIRS})
endif()

# Optional check for Apple-specific freenect path issues
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
    message(WARNING 
      "libfreenect.h not found in FREENECT_INCLUDE_DIRS. "
      "Please verify your libfreenect installation."
    )
  endif()
endif()

#-----------------------------------------------------------------------------
# 6) Build the executable and link with libfreenect + NDI
#-----------------------------------------------------------------------------
add_executable(kinect_ndi_cross_platform kinect_ndi_cross_platform.cpp)
target_link_libraries(kinect_ndi_cross_platform 
  ${FREENECT_LIBRARIES} 
  "${NDI_LIB_PATH}"
)

message(STATUS "Configuration complete.")
