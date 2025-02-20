#!/bin/bash
# install_dependencies.sh
# This script installs required dependencies for the Kinect-to-NDI project.

set -e

# Function: print a header message.
print_header() {
  echo "=============================================="
  echo "$1"
  echo "=============================================="
}

# Detect operating system.
OS=$(uname)
NDI_SDK_PATH=""

if [[ "$OS" == "Darwin" ]]; then
  # macOS
  print_header "Detected macOS"
  # Check if Homebrew is installed.
  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew not found. Please install Homebrew from https://brew.sh/ and re-run this script."
    exit 1
  fi

  print_header "Updating Homebrew and Installing Dependencies"
  brew update
  brew install libfreenect cmake pkg-config

  # Set expected NDI SDK location on macOS.
  NDI_SDK_PATH="/Library/NDI SDK for Apple"
elif [[ "$OS" == "Linux" ]]; then
  print_header "Detected Linux"
  # Check for apt-get (Debian/Ubuntu) or instruct the user if not found.
  if ! command -v apt-get >/dev/null 2>&1; then
    echo "This script currently supports Debian-based systems. Please install dependencies manually."
    exit 1
  fi

  print_header "Updating apt-get and Installing Dependencies"
  sudo apt-get update
  sudo apt-get install -y libfreenect-dev pkg-config cmake build-essential

  # Set expected NDI SDK location on Linux.
  NDI_SDK_PATH="/opt/ndi_sdk"
else
  echo "Unsupported OS: $OS. Please install dependencies manually."
  exit 1
fi

# Check for the NDI SDK.
if [ ! -d "$NDI_SDK_PATH" ]; then
  echo "NDI SDK not found at: $NDI_SDK_PATH"
  echo "Please download the NDI SDK for your platform from:"
  echo "    https://www.ndi.tv/sdk/"
  echo "Then extract or install it to the above location or adjust the NDI_SDK_PATH variable in this script."
  exit 1
else
  echo "NDI SDK found at: $NDI_SDK_PATH"
fi

print_header "Dependencies Installation Complete"

# (Optional) Build the project if a build script is present.
if [ -f "CMakeLists.txt" ]; then
  echo "Found CMakeLists.txt. You may now create a build directory and compile the project:"
  echo "   mkdir -p build && cd build"
  echo "   cmake -DNDI_SDK_DIR=\"$NDI_SDK_PATH\" .."
  echo "   make"
else
  echo "No CMakeLists.txt found in the current directory. Skipping build instructions."
fi

echo "Setup complete."
