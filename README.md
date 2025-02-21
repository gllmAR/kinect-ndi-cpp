# Kinect NDI Transmitter

A cross-platform C++ application that streams Kinect data (IR, RGB, and Depth) over NDI. It uses libfreenect to access Kinect sensor data and the NewTek NDI SDK to broadcast video streams over IP. The application features auto-detection and auto-reconnection of the Kinect device.

## Features

- **Multi-Stream Support:** Enable IR, RGB, and/or depth streaming via command-line options.
- **Auto-Reconnect:** Automatically detects and reconnects if the Kinect is disconnected.
- **NDI Output:** Transmits video frames as NDI streams compatible with any NDI receiver.
- **Cross-Platform:** Supports macOS, Linux, and Windows (with appropriate dependency installation).

## Dependencies

- **libfreenect:** Access Kinect data.  
  - **macOS:** Install via Homebrew:  
    ```bash
    brew install libfreenect
    ```  
  - **Linux:** Install via your package manager (e.g., `apt-get install libfreenect-dev` on Debian/Ubuntu).  
  - **Windows:** Build from source or use pre-built binaries.
- **NDI SDK:**  
  - **macOS:** Download the NDI SDK for Apple from [NDI SDK](https://www.ndi.tv/sdk/). Default install path is `/Library/NDI SDK for Apple`.
  - **Linux/Windows:** Download the appropriate NDI SDK version from [NDI SDK](https://www.ndi.tv/sdk/).
- **CMake** and **pkg-config** (or equivalent on Windows).

## Build Instructions

### macOS / Linux

1. **Install Dependencies:**  
   For macOS, run the provided dependency script:
   ```bash
   chmod +x install_dependencies.sh
   ./install_dependencies.sh
   ```
   (Ensure the NDI SDK is installed at the expected location or adjust the `NDI_SDK_DIR` variable.)

2. **Build the Project:**
   ```bash
   rm -rf build
   mkdir build && cd build
   cmake -DNDI_SDK_DIR="/Library/NDI SDK for Apple" ..
   make
   ```

### Windows

- Install or build **libfreenect** and the **NDI SDK**.
- Use CMake to generate a Visual Studio solution:
  ```bash
  mkdir build && cd build
  cmake -G "Visual Studio 16 2019" -DNDI_SDK_DIR="C:/Path/To/NDI_SDK" ..
  ```
- Open the generated solution in Visual Studio, build the project, and run it.

## Run Instructions

Use command-line options to select which streams to enable:

- **Stream RGB and Depth:**
  ```bash
  sudo ./kinect_ndi_cross_platform --rgb --depth
  ```
- **Stream only IR:**
  ```bash
  sudo ./kinect_ndi_cross_platform --ir
  ```
- **Display Help:**
  ```bash
  ./kinect_ndi_cross_platform --help
  ```

## License

This project is licensed under the MIT License.

