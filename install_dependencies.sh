#!/bin/bash
# install_dependencies.sh
# This script installs required dependencies for the Kinect-to-NDI project,
# and automatically downloads and installs the NDI SDK for Linux if not found.

set -e

# Utility functions.
log() {
  echo "[LOG] $1"
}

error_exit() {
  echo "[ERROR] $1"
  exit 1
}

print_header() {
  echo "=============================================="
  echo "$1"
  echo "=============================================="
}

# Function: download and install the NDI SDK for Linux.
get_NDI() {
  log "Downloading NDI SDK for Linux."
  # Download the tarball to /tmp.
  curl -s -L https://downloads.ndi.tv/SDK/NDI_SDK_Linux/Install_NDI_SDK_v5_Linux.tar.gz \
    -o /tmp/Install_NDI_SDK_v5_Linux.tar.gz || error_exit "Failed to download NDI SDK."
  
  log "Extracting NDI SDK tarball."
  tar xvzf /tmp/Install_NDI_SDK_v5_Linux.tar.gz -C /tmp/ \
    || error_exit "Failed to extract NDI SDK tarball."
  
  log "Running NDI SDK installer."
  yes y | bash /tmp/Install_NDI_SDK_v5_Linux.sh > /tmp/ndi_install.log 2>&1 \
    || error_exit "Failed to install NDI SDK. Check /tmp/ndi_install.log for details."
}

# Optional: Function to install NDI libraries (if needed).
install_NDI_LIB() {
  # Use NDI_SDK_PATH as the base directory.
  local DIR="$NDI_SDK_PATH"
  ARCH=$(uname -m)
  local extracted_dir="$DIR/lib/NDI SDK for Linux/bin"
  local lib_path="/usr/lib/${ARCH}-linux-gnu/"
  local source_path="${extracted_dir}/${ARCH}-linux-gnu"

  log "Installing NDI libraries to $lib_path."

  if [ -d "$source_path" ]; then
    sudo cp "$source_path"/* "$lib_path" || error_exit "Failed to copy NDI libraries from $source_path."
    sudo ldconfig || error_exit "Failed to update shared library cache."
  else
    error_exit "Expected source directory $source_path does not exist."
  fi
}

# Detect operating system.
OS=$(uname)
NDI_SDK_PATH=""

if [[ "$OS" == "Darwin" ]]; then
  # macOS
  print_header "Detected macOS"
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
  if ! command -v apt-get >/dev/null 2>&1; then
    echo "This script currently supports Debian-based systems. Please install dependencies manually."
    exit 1
  fi

  print_header "Updating apt-get and Installing Dependencies"
  sudo apt-get update
  sudo apt-get install -y libfreenect-dev pkg-config cmake build-essential curl

  # Set expected NDI SDK location on Linux.
  NDI_SDK_PATH="/opt/ndi_sdk"

  # If the NDI SDK directory does not exist, auto download and install it.
  if [ ! -d "$NDI_SDK_PATH" ]; then
    log "NDI SDK not found at $NDI_SDK_PATH. Initiating download and installation."
    get_NDI
    # Optionally, if you need to install the libraries:
    # install_NDI_LIB
  else
    log "NDI SDK found at: $NDI_SDK_PATH"
  fi

else
  echo "Unsupported OS: $OS. Please install dependencies manually."
  exit 1
fi

print_header "Dependencies Installation Complete"

# (Optional) Build the project if a CMakeLists.txt is present.
if [ -f "CMakeLists.txt" ]; then
  echo "Found CMakeLists.txt. You may now create a build directory and compile the project:"
  echo "   mkdir -p build && cd build"
  echo "   cmake -DNDI_SDK_DIR=\"$NDI_SDK_PATH\" .."
  echo "   make"
else
  echo "No CMakeLists.txt found in the current directory. Skipping build instructions."
fi

echo "Setup complete."
