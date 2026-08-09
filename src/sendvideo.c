#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <linux/videodev2.h>

#define DEST_IP "169.254.80.11"
#define DEST_PORT 5000

#define CAM_WIDTH 640
#define CAM_HEIGHT 480
#define STREAM_WIDTH 320
#define STREAM_HEIGHT 240

#define PACKET_PERIOD_MS 0
#define PACKET_SIZE 1202
#define PIXELS_PER_PACKET (PACKET_SIZE/2 - 1)
#define PACKETS_PER_FRAME STREAM_WIDTH*STREAM_HEIGHT/PIXELS_PER_PACKET

#define CLAMP_BYTE(x) ( (x) < 0 ? 0 : ( (x) > 255 ? 255 : (x)) )

void transmit_frame(uint8_t* buf, int sock_fd, struct sockaddr_in* dest_addr);
void convert_payload(uint8_t* src, uint8_t* dest);

void init_sock(int* sock_fd, struct sockaddr_in* dest_addr);

int main() {
    int sock_fd;
    struct sockaddr_in dest_addr;
    init_sock(&sock_fd, &dest_addr);
    
    const char *dev_name = "/dev/video0";
    int fd = open(dev_name, O_RDWR | O_NONBLOCK, 0);
    if (fd < 0) {
        perror("Opening video device");
        return 1;
    }


    //Set video format
    struct v4l2_format fmt;
    memset(&fmt, 0, sizeof(fmt));
    fmt.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    fmt.fmt.pix.width       = 640;
    fmt.fmt.pix.height      = 480;
    fmt.fmt.pix.pixelformat = V4L2_PIX_FMT_YUYV;
    fmt.fmt.pix.field       = V4L2_FIELD_ANY;

    if (ioctl(fd, VIDIOC_S_FMT, &fmt) < 0) {
        perror("Setting Pixel Format");
        close(fd);
        return 1;
    }

    //Request buffers
    struct v4l2_requestbuffers req;
    memset(&req, 0, sizeof(req));
    req.count = 1;
    req.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    req.memory = V4L2_MEMORY_MMAP;

    if (ioctl(fd, VIDIOC_REQBUFS, &req) < 0) {
        perror("Requesting Buffers");
        close(fd);
        return 1;
    }

    //Map Buffer
    struct v4l2_buffer buf;
    memset(&buf, 0, sizeof(buf));
    buf.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    buf.memory = V4L2_MEMORY_MMAP;
    buf.index = 0;

    if (ioctl(fd, VIDIOC_QUERYBUF, &buf) < 0) {
        perror("Querying Buffer");
        close(fd);
        return 1;
    }

    void *buffer_start = mmap(NULL, buf.length, PROT_READ | PROT_WRITE, MAP_SHARED, fd, buf.m.offset);
    if (buffer_start == MAP_FAILED) {
        perror("Mapping Buffer");
        close(fd);
        return 1;
    }

    //Queue buffer
    if (ioctl(fd, VIDIOC_QBUF, &buf) < 0) {
        perror("Queuing Buffer");
        munmap(buffer_start, buf.length);
        close(fd);
        return 1;
    }

    //Begin streaming
    enum v4l2_buf_type type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    if (ioctl(fd, VIDIOC_STREAMON, &type) < 0) {
        perror("Starting Stream");
        munmap(buffer_start, buf.length);
        close(fd);
        return 1;
    }

    while(1){
        //Capture a Frame using select() for timeout management
        fd_set fds;
        FD_ZERO(&fds);
        FD_SET(fd, &fds);
        struct timeval tv = {2, 0}; // 2-second timeout

        int r = select(fd + 1, &fds, NULL, NULL, &tv);
        if (r > 0) {
            struct v4l2_buffer cap_buf;
            memset(&cap_buf, 0, sizeof(cap_buf));
            cap_buf.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
            cap_buf.memory = V4L2_MEMORY_MMAP;

            if (ioctl(fd, VIDIOC_DQBUF, &cap_buf) >= 0) {
                printf("Successfully captured frame. Size: %u bytes\n", cap_buf.bytesused);
                // buffer_start contains raw YUYV frame data ready for processing.

                transmit_frame(buffer_start, sock_fd, &dest_addr);
                
                ioctl(fd, VIDIOC_QBUF, &cap_buf);
            }
        } else {
            fprintf(stderr, "Capture timeout or error.\n");
            return 1;
        }
    }

    // 7. Cleanup
    ioctl(fd, VIDIOC_STREAMOFF, &type);
    munmap(buffer_start, buf.length);
    close(fd);
    return 0;

}

void init_sock(int* sock_fd, struct sockaddr_in* dest_addr){
    *sock_fd = socket(AF_INET, SOCK_DGRAM, 0);
    if (*sock_fd < 0) {
        perror("Socket creation failed");
        exit(EXIT_FAILURE);
    }
    //Configure the destination address structure
    memset(dest_addr, 0, sizeof(*dest_addr));
    dest_addr->sin_family = AF_INET;
    dest_addr->sin_port = htons(DEST_PORT);
    if (inet_pton(AF_INET, DEST_IP, &dest_addr->sin_addr) <= 0) {
        perror("Invalid address or address not supported");
        close(*sock_fd);
        exit(EXIT_FAILURE);
    }
}

uint16_t frame_r, frame_c;
uint8_t send_buf[PACKET_SIZE];

void transmit_frame(uint8_t* buf, int sock_fd, struct sockaddr_in* dest_addr){
    frame_r = 0;
    frame_c = 0;
    for(uint8_t i = 0; i < PACKETS_PER_FRAME; i++){
        send_buf[0] = i;
        send_buf[1] = 0;

        convert_payload(buf, send_buf+2);

        int bytes_sent = sendto(sock_fd, send_buf, PACKET_SIZE, 0, (struct sockaddr *)dest_addr, sizeof(*dest_addr));
        if(bytes_sent < PACKET_SIZE){
            fprintf(stderr, "Failed to send.\n");
            exit(EXIT_FAILURE);
        }

        usleep(PACKET_PERIOD_MS * 1000);
    }
}

void convert_payload(uint8_t* src, uint8_t* dest) {
    int pixels_added = 0;
    while (pixels_added < PIXELS_PER_PACKET && frame_r < CAM_HEIGHT) {
        uint32_t byte_idx = (CAM_WIDTH * frame_r + frame_c) * 2;
        
        int16_t Y = src[byte_idx];
        int16_t U = src[byte_idx + 1];
        int16_t V = src[byte_idx + 3];

        int r_uc = Y + 1.402 * (V - 128);
        int g_uc = Y - 0.344136 * (U - 128) - 0.714136 * (V - 128);
        int b_uc = Y + 1.772 * (U - 128);


        uint8_t R = CLAMP_BYTE(r_uc);
        uint8_t G = CLAMP_BYTE(g_uc);
        uint8_t B = CLAMP_BYTE(b_uc);

        // uint8_t R = 0;
        // uint8_t G = 0;
        // uint8_t B = 255;

        dest[pixels_added * 2] = (G & 0b11110000) | ((B & 0b11110000) >> 4);
        dest[pixels_added * 2 + 1] = (R & 0b11110000) >> 4;
        
        pixels_added++;
        frame_c += 2;
        
        if (frame_c >= CAM_WIDTH) {
            frame_c = 0;
            frame_r += 2;
        }
    }
}