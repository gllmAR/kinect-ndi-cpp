#!/usr/bin/env bash
#
# setup.sh
#
# Automate the installation of Kinect-to-NDI software:
#   1) Run dependencies installation.
#   2) Build the project using CMake.
#   3) (Linux only) Optionally create a systemd user service to launch it on login.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ---------------------------------------------------------
# Helper functions
# ---------------------------------------------------------
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

# ---------------------------------------------------------
# Detect operating system
# ---------------------------------------------------------
OS="$(uname)"
case "$OS" in
  "Darwin")
    PLATFORM="macOS"
    ;;
  "Linux")
    PLATFORM="Linux"
    ;;
  *)
    PLATFORM="Unknown"
    ;;
esac

print_header "Kinect-to-NDI Setup Script"
log "Detected platform: $PLATFORM"

# ---------------------------------------------------------
# 1) Run install_dependencies.sh
# ---------------------------------------------------------
log "Running install_dependencies.sh ..."
chmod +x "${SCRIPT_DIR}/install_dependencies.sh"
"${SCRIPT_DIR}/install_dependencies.sh"

# ---------------------------------------------------------
# 2) Create build folder, run CMake, build
# ---------------------------------------------------------
print_header "Building Kinect-to-NDI Project"
BUILD_DIR="${SCRIPT_DIR}/build"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# If you want to pass extra options to CMake, adjust here.
# e.g.: cmake -DNDI_SDK_DIR="/opt/ndi_sdk" -DCMAKE_BUILD_TYPE=Release ..
cmake ..
make -j$(nproc || sysctl -n hw.ncpu || echo 4)

cd "$SCRIPT_DIR"
log "Build complete."

# ---------------------------------------------------------
# 3) (Linux only) Optionally create a systemd user service
# ---------------------------------------------------------
if [[ "$PLATFORM" == "Linux" ]]; then
  print_header "Optionally Create Systemd User Service"

  # Ask if the user wants to create a systemd user service
  read -rp "Would you like to create and enable a systemd user service for Kinect-to-NDI? [Y/n]: " REPLY
  REPLY="${REPLY,,}"  # to lowercase
  if [[ "$REPLY" =~ ^(yes|y|)$ ]]; then

    # Decide where the built binary is
    # For convenience, we’ll refer directly to the build folder’s binary:
    EXEC_PATH="${BUILD_DIR}/kinect_ndi_cross_platform"

    # If you prefer to install it system-wide, you could do:
    # sudo cp "${EXEC_PATH}" /usr/local/bin/kinect_ndi_cross_platform
    # EXEC_PATH="/usr/local/bin/kinect_ndi_cross_platform"

    # (Optional) Ask the user which streams to enable by default
    echo "Which streams do you want to enable by default when the service runs?"
    echo "  1) IR only (--ir)"
    echo "  2) RGB only (--rgb)"
    echo "  3) Depth only (--depth)"
    echo "  4) IR + Depth (--ir --depth)"
    echo "  5) RGB + Depth (--rgb --depth)"
    echo "  6) No default arguments (you can edit the service later)"
    read -rp "Enter a number [1-6]: " STREAM_CHOICE

    SERVICE_ARGS=""
    case "$STREAM_CHOICE" in
      1) SERVICE_ARGS="--ir" ;;
      2) SERVICE_ARGS="--rgb" ;;
      3) SERVICE_ARGS="--depth" ;;
      4) SERVICE_ARGS="--ir --depth" ;;
      5) SERVICE_ARGS="--rgb --depth" ;;
      6) SERVICE_ARGS="" ;;
      *) SERVICE_ARGS="--rgb --depth" ;;
    esac

    # Create the systemd user service file
    # We'll place it in ~/.config/systemd/user/kinect-ndi.service
    SERVICE_DIR="${HOME}/.config/systemd/user"
    mkdir -p "$SERVICE_DIR"
    SERVICE_FILE="${SERVICE_DIR}/kinect-ndi.service"

    cat <<EOF > "$SERVICE_FILE"
# systemd user service for Kinect-to-NDI
[Unit]
Description=Kinect-to-NDI Streaming Service
After=network.target

[Service]
ExecStart=${EXEC_PATH} ${SERVICE_ARGS}
Restart=on-failure

# If you want the service to continue running when you're not logged in,
# you can enable linger for your user with:
#   sudo loginctl enable-linger \$USER
# That way, user services can continue running after logout.

[Install]
WantedBy=default.target
EOF

    log "Created user service file at: $SERVICE_FILE"

    # Reload user systemd units
    systemctl --user daemon-reload

    # Enable (to start on login) and optionally start now
    systemctl --user enable kinect-ndi.service
    read -rp "Do you want to start the service now? [Y/n]: " REPLY
    REPLY="${REPLY,,}"  # to lowercase
    if [[ "$REPLY" =~ ^(yes|y|)$ ]]; then
      systemctl --user start kinect-ndi.service
      log "kinect-ndi.service started."
    else
      log "You can start it any time with: systemctl --user start kinect-ndi.service"
    fi

    echo "------------------------------------------------------"
    echo "Service installation complete."
    echo "Note: If you want the service to run at boot even"
    echo "      when you're not logged in, consider using:"
    echo "         sudo loginctl enable-linger \$USER"
    echo "------------------------------------------------------"
  else
    log "Skipping systemd user service setup."
  fi
else
  print_header "Systemd Service (macOS or other OS)"
  echo "Systemd user services are not typically used on this OS."
  echo "Skipping service setup."
fi

print_header "Setup Complete!"
echo "You may now run the Kinect-to-NDI application manually, e.g.:"
echo "  ${BUILD_DIR}/kinect_ndi_cross_platform --ir --depth"
echo ""
echo "Or if you set up the systemd user service (Linux), it may be running already."
echo ""
echo "Enjoy!"
