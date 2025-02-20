cmake_minimum_required(VERSION 3.10)
project(KinectNDI)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find libfreenect using pkg-config.
find_package(PkgConfig REQUIRED)
pkg_check_modules(FREENECT REQUIRED libfreenect)

include_directories(${FREENECT_INCLUDE_DIRS})
# Adjust the include path for the NDI SDK if necessary. For example:
# include_directories("/path/to/NDI_SDK/Include")

add_executable(kinect_ndi_cross_platform kinect_ndi_cross_platform.cpp)

# Link against libfreenect and the NDI library.
target_link_libraries(kinect_ndi_cross_platform ${FREENECT_LIBRARIES} ndi)
