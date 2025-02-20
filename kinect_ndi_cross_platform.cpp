#include <iostream>
#include <mutex>
#include <atomic>
#include <thread>
#include <chrono>
#include <vector>
#include <cstring>
#include <string>

#ifdef _WIN32
  #include <windows.h>
#endif

// Use the correct header name for libfreenect.
#include <libfreenect.h>
#include <Processing.NDI.Lib.h>

// Frame dimensions.
constexpr int WIDTH  = 640;
constexpr int HEIGHT = 480;

// Global flags from command‑line.
bool enable_rgb   = false;
bool enable_ir    = false;
bool enable_depth = false;

// Determines the number of channels for video data (1 for IR, 3 for RGB).
int videoChannels = 0;

// Global buffers and synchronization for video frames.
std::mutex videoMutex;
std::atomic<bool> newVideoFrame(false);
std::vector<uint8_t> videoBuffer;  // Size: WIDTH * HEIGHT * videoChannels

// Global buffers and synchronization for depth frames.
std::mutex depthMutex;
std::atomic<bool> newDepthFrame(false);
std::vector<uint16_t> depthBuffer; // Size: WIDTH * HEIGHT

// Callback for video frames (IR or RGB).
void VideoCallback(freenect_device* dev, void* video, uint32_t timestamp) {
    std::lock_guard<std::mutex> lock(videoMutex);
    size_t frameSize = WIDTH * HEIGHT * videoChannels;
    if (videoBuffer.size() != frameSize)
        videoBuffer.resize(frameSize);
    std::memcpy(videoBuffer.data(), video, frameSize);
    newVideoFrame = true;
}

// Callback for depth frames.
void DepthCallback(freenect_device* dev, void* depth, uint32_t timestamp) {
    std::lock_guard<std::mutex> lock(depthMutex);
    size_t frameSize = WIDTH * HEIGHT;
    if (depthBuffer.size() != frameSize)
        depthBuffer.resize(frameSize);
    std::memcpy(depthBuffer.data(), depth, frameSize * sizeof(uint16_t));
    newDepthFrame = true;
}

// Print help/usage information.
void PrintUsage(const char* progName) {
    std::cout << "Usage: " << progName << " [--ir | --rgb] [--depth] [--help]\n"
              << "Options:\n"
              << "  --ir      Enable infrared (IR) streaming (8-bit grayscale).\n"
              << "  --rgb     Enable RGB video streaming.\n"
              << "  --depth   Enable depth streaming.\n"
              << "  --help    Display this help message.\n"
              << "\nNotes:\n"
              << "  You can enable either --ir or --rgb for the video stream (not both simultaneously).\n"
              << "  Depth streaming can be enabled along with either video mode.\n";
}

int main(int argc, char** argv) {
    // Parse command-line arguments.
    if (argc < 2) {
        PrintUsage(argv[0]);
        return 0;
    }
    for (int i = 1; i < argc; i++) {
        std::string arg = argv[i];
        if (arg == "--help" || arg == "-h") {
            PrintUsage(argv[0]);
            return 0;
        } else if (arg == "--ir") {
            enable_ir = true;
        } else if (arg == "--rgb") {
            enable_rgb = true;
        } else if (arg == "--depth") {
            enable_depth = true;
        } else {
            std::cerr << "Unknown argument: " << arg << "\n";
            PrintUsage(argv[0]);
            return 1;
        }
    }
    if (enable_ir && enable_rgb) {
        std::cerr << "Error: Cannot enable both IR and RGB streaming simultaneously.\n";
        return 1;
    }
    if (!enable_ir && !enable_rgb && !enable_depth) {
        std::cerr << "Error: No streaming mode enabled. Use --ir, --rgb, and/or --depth.\n";
        return 1;
    }
    // Set the number of video channels based on the mode.
    if (enable_ir) {
        videoChannels = 1;
    } else if (enable_rgb) {
        videoChannels = 3;
    }

    // Initialize the NDI library.
    if (!NDIlib_initialize()) {
        std::cerr << "Cannot run NDI – please ensure the NDI runtime is installed." << std::endl;
        return 1;
    }
    
    // Create NDI sender instances.
    NDIlib_send_instance_t ndiSenderVideo = nullptr;
    if (enable_ir || enable_rgb) {
        NDIlib_send_create_t ndiSendDesc;
        ndiSendDesc.p_ndi_name = (enable_ir ? "Kinect IR Stream" : "Kinect RGB Stream");
        ndiSenderVideo = NDIlib_send_create(&ndiSendDesc);
    }
    NDIlib_send_instance_t ndiSenderDepth = nullptr;
    if (enable_depth) {
        NDIlib_send_create_t ndiSendDesc;
        ndiSendDesc.p_ndi_name = "Kinect Depth Stream";
        ndiSenderDepth = NDIlib_send_create(&ndiSendDesc);
    }

    std::cout << "Starting Kinect streaming with auto-detection and reconnection..." << std::endl;

    // Outer loop: attempt to (re)connect to the Kinect device.
    while (true) {
        freenect_context* f_ctx = nullptr;
        freenect_device* f_dev = nullptr;

        // Try initializing the Kinect context.
        if (freenect_init(&f_ctx, nullptr) < 0) {
            std::cerr << "freenect_init() failed. No Kinect found. Retrying in 5 seconds..." << std::endl;
            std::this_thread::sleep_for(std::chrono::seconds(5));
            continue;
        }
        // Try opening the first available Kinect.
        if (freenect_open_device(f_ctx, &f_dev, 0) < 0) {
            std::cerr << "Could not open Kinect device. Retrying in 5 seconds..." << std::endl;
            freenect_shutdown(f_ctx);
            std::this_thread::sleep_for(std::chrono::seconds(5));
            continue;
        }

        // Set up video stream if enabled.
        if (enable_ir || enable_rgb) {
            freenect_set_video_callback(f_dev, VideoCallback);
            freenect_frame_mode video_mode;
            if (enable_ir) {
                video_mode = freenect_find_video_mode(FREENECT_RESOLUTION_MEDIUM, FREENECT_VIDEO_IR_8BIT);
            } else if (enable_rgb) {
                video_mode = freenect_find_video_mode(FREENECT_RESOLUTION_MEDIUM, FREENECT_VIDEO_RGB);
            }
            if (freenect_set_video_mode(f_dev, video_mode) < 0) {
                std::cerr << "Could not start the video stream. Reconnecting..." << std::endl;
                freenect_close_device(f_dev);
                freenect_shutdown(f_ctx);
                std::this_thread::sleep_for(std::chrono::seconds(5));
                continue;
            }
        }
        // Set up depth stream if enabled.
        if (enable_depth) {
            freenect_set_depth_callback(f_dev, DepthCallback);
            freenect_frame_mode depth_mode = freenect_find_depth_mode(FREENECT_RESOLUTION_MEDIUM, FREENECT_DEPTH_11BIT);
            if (freenect_set_depth_mode(f_dev, depth_mode) < 0) {
                std::cerr << "Could not start the depth stream. Reconnecting..." << std::endl;
                if (enable_ir || enable_rgb)
                    freenect_stop_video(f_dev);
                freenect_close_device(f_dev);
                freenect_shutdown(f_ctx);
                std::this_thread::sleep_for(std::chrono::seconds(5));
                continue;
            }
        }

        std::cout << "Kinect connected. Streaming data over NDI..." << std::endl;

        // Inner loop: process Kinect events and transmit frames.
        bool kinect_active = true;
        while (kinect_active) {
            int ret = freenect_process_events(f_ctx);
            if (ret < 0) {
                std::cerr << "Kinect disconnected or error encountered (code " << ret << "). Reconnecting..." << std::endl;
                kinect_active = false;
                break;
            }

            // Process video frame (IR or RGB) if available.
            if ((enable_ir || enable_rgb) && newVideoFrame.load()) {
                std::vector<uint8_t> rgbaFrame(WIDTH * HEIGHT * 4);
                std::vector<uint8_t> localVideoBuffer;
                {
                    std::lock_guard<std::mutex> lock(videoMutex);
                    localVideoBuffer = videoBuffer;
                    newVideoFrame = false;
                }
                if (enable_ir) {
                    // For IR, replicate the single channel into R, G, and B.
                    for (int i = 0; i < WIDTH * HEIGHT; i++) {
                        uint8_t gray = localVideoBuffer[i];
                        rgbaFrame[i * 4 + 0] = gray;  // Blue
                        rgbaFrame[i * 4 + 1] = gray;  // Green
                        rgbaFrame[i * 4 + 2] = gray;  // Red
                        rgbaFrame[i * 4 + 3] = 255;   // Alpha
                    }
                } else if (enable_rgb) {
                    // For RGB, convert from RGB to BGRA.
                    for (int i = 0; i < WIDTH * HEIGHT; i++) {
                        uint8_t r = localVideoBuffer[i * 3 + 0];
                        uint8_t g = localVideoBuffer[i * 3 + 1];
                        uint8_t b = localVideoBuffer[i * 3 + 2];
                        rgbaFrame[i * 4 + 0] = b; // Blue
                        rgbaFrame[i * 4 + 1] = g; // Green
                        rgbaFrame[i * 4 + 2] = r; // Red
                        rgbaFrame[i * 4 + 3] = 255; // Alpha
                    }
                }
                NDIlib_video_frame_v2_t videoFrame;
                videoFrame.xres = WIDTH;
                videoFrame.yres = HEIGHT;
                videoFrame.FourCC = NDIlib_FourCC_type_BGRA;
                videoFrame.frame_rate_N = 30;
                videoFrame.frame_rate_D = 1;
                videoFrame.picture_aspect_ratio = static_cast<float>(WIDTH) / HEIGHT;
                videoFrame.p_data = rgbaFrame.data();
                videoFrame.line_stride_in_bytes = WIDTH * 4;
                if (ndiSenderVideo)
                    NDIlib_send_send_video_async_v2(ndiSenderVideo, &videoFrame);
            }

            // Process depth frame if available.
            if (enable_depth && newDepthFrame.load()) {
                std::vector<uint8_t> rgbaFrame(WIDTH * HEIGHT * 4);
                std::vector<uint16_t> localDepthBuffer;
                {
                    std::lock_guard<std::mutex> lock(depthMutex);
                    localDepthBuffer = depthBuffer;
                    newDepthFrame = false;
                }
                // Map 11-bit depth (0–2047) to an 8-bit grayscale image.
                for (int i = 0; i < WIDTH * HEIGHT; i++) {
                    uint16_t depthVal = localDepthBuffer[i];
                    uint8_t gray = static_cast<uint8_t>((depthVal * 255) / 2047);
                    rgbaFrame[i * 4 + 0] = gray; // Blue
                    rgbaFrame[i * 4 + 1] = gray; // Green
                    rgbaFrame[i * 4 + 2] = gray; // Red
                    rgbaFrame[i * 4 + 3] = 255;  // Alpha
                }
                NDIlib_video_frame_v2_t depthFrame;
                depthFrame.xres = WIDTH;
                depthFrame.yres = HEIGHT;
                depthFrame.FourCC = NDIlib_FourCC_type_BGRA;
                depthFrame.frame_rate_N = 30;
                depthFrame.frame_rate_D = 1;
                depthFrame.picture_aspect_ratio = static_cast<float>(WIDTH) / HEIGHT;
                depthFrame.p_data = rgbaFrame.data();
                depthFrame.line_stride_in_bytes = WIDTH * 4;
                if (ndiSenderDepth)
                    NDIlib_send_send_video_async_v2(ndiSenderDepth, &depthFrame);
            }
            std::this_thread::sleep_for(std::chrono::milliseconds(10));
        }  // End inner loop

        // Kinect disconnected or error occurred; clean up.
        if (enable_ir || enable_rgb)
            freenect_stop_video(f_dev);
        if (enable_depth)
            freenect_stop_depth(f_dev);
        freenect_close_device(f_dev);
        freenect_shutdown(f_ctx);
        std::cerr << "Kinect connection lost. Attempting to reconnect in 5 seconds..." << std::endl;
        std::this_thread::sleep_for(std::chrono::seconds(5));
    }  // End outer loop

    // Cleanup (never reached in this infinite-loop design).
    if (ndiSenderVideo)
        NDIlib_send_destroy(ndiSenderVideo);
    if (ndiSenderDepth)
        NDIlib_send_destroy(ndiSenderDepth);
    NDIlib_destroy();
    return 0;
}
