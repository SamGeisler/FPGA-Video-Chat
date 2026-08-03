#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>
#include <errno.h>
#include <time.h>
#include <SDL3/SDL.h>
#include <arpa/inet.h>


#define PORT 5000
#define SWIDTH 320
#define SHEIGHT 240
#define BPP 2 // 16-bit RGB565 is 2 bytes per pixel
#define FRAME_SIZE (SWIDTH * SHEIGHT * BPP)
#define BUFFER_SIZE 65536 // Max UDP datagram size

#define PACKET_SIZE 1202
#define PACKETS_PER_FRAME 128
#define FRAME_TOUT_MS 750


#define TARGET_IP "169.254.80.10"

typedef unsigned long long ull;

void copy_convert(uint8_t* dest_rgb24, uint8_t* src_rgb16);

ull curr_ms() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (ull)(ts.tv_sec * 1000 + (ts.tv_nsec / 1000000));
}

int init_SDL(SDL_Window** window, SDL_Renderer** renderer, SDL_Texture** texture) {
    if (!SDL_Init(SDL_INIT_VIDEO)) {
        fprintf(stderr, "Could not initialize SDL: %s\n", SDL_GetError());
        return -1;
    }

    *window = SDL_CreateWindow("Video", SWIDTH, SHEIGHT, 0); 

    *renderer = SDL_CreateRenderer(*window, NULL);

    *texture = SDL_CreateTexture(
        *renderer,
        SDL_PIXELFORMAT_RGB24,        // Expecting standard RGB bytes
        SDL_TEXTUREACCESS_STREAMING,  // Optimized for frequent updates
        SWIDTH, SHEIGHT
    );
    
    SDL_RenderTexture(*renderer, *texture, NULL, NULL);

    return 0;
}

int main(int argc, char** argv) {
    (void)argc; (void)argv;

    //Socket setup
    int sockfd;
    struct sockaddr_in servaddr;
    uint8_t buffer[BUFFER_SIZE];

    sockfd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if (sockfd < 0) {
        fprintf(stderr, "Socket creation failed with error: %s\n", strerror(errno));
        return 1;
    }

    memset(&servaddr, 0, sizeof(servaddr));
    servaddr.sin_family = AF_INET;
    servaddr.sin_port = htons(PORT);

    if (inet_pton(AF_INET, TARGET_IP, &servaddr.sin_addr) <= 0) {
        fprintf(stderr, "Socket creation failed with error: %s\n", strerror(errno));
        return 1;
    }

    // Set socket to non-blocking
    int flags = fcntl(sockfd, F_GETFL, 0);
    fcntl(sockfd, F_SETFL, flags | O_NONBLOCK);

    if (bind(sockfd, (const struct sockaddr *)&servaddr, sizeof(servaddr)) < 0) {
        fprintf(stderr, "Bind failed with error: %s\n", strerror(errno));
        close(sockfd);
        return 1;
    }

    SDL_Window* window;
    SDL_Renderer* renderer;
    SDL_Texture* texture;

    if (init_SDL(&window, &renderer, &texture)) {
        fprintf(stderr, "Failed to init SDL.\n");
        return -1;
    }

    uint8_t* draw_buf = (uint8_t*)malloc(SWIDTH * SHEIGHT * 3 * sizeof(uint8_t));
    uint8_t* recv_frame_buf = (uint8_t*)malloc(SWIDTH * SHEIGHT * 2 * sizeof(uint8_t));

    if(!draw_buf || !recv_frame_buf){
        printf("FAILED TO ALLOCATE BUFFERS\n");
        return 1;
    }

    SDL_Event e;
    int running = 1;

    ull last_frame_time = 0;

    while (running) {
        //Receive data
        int n = recvfrom(sockfd, (char *)buffer, BUFFER_SIZE, 0, NULL, NULL);
        
        if (n < 0) {
            goto render_frame;
        }
        if (n != PACKET_SIZE) {
            printf("RECEIVED PACKET OF SIZE %d\n", n);
            goto render_frame;
        }

        uint16_t seq_num = ((uint16_t)buffer[0] << 8) + buffer[1];
        printf("seq_num=%d\n",seq_num);

        memcpy(recv_frame_buf + (seq_num * (PACKET_SIZE-2)), buffer+2, PACKET_SIZE-2);

        if (seq_num == PACKETS_PER_FRAME-1) {
            copy_convert(draw_buf, recv_frame_buf);
            last_frame_time = curr_ms();
        } else if (curr_ms() - last_frame_time >= FRAME_TOUT_MS) {
            printf("FRAME TIMEOUT\n");
            copy_convert(draw_buf, recv_frame_buf);
            last_frame_time = curr_ms();
        }

        render_frame:
        // Handle window events
        while (SDL_PollEvent(&e)) {
            if (e.type == SDL_EVENT_QUIT) {
                running = 0;
            }
        }

        //Render new frame
        SDL_UpdateTexture(texture, NULL, draw_buf, SWIDTH * 3);

        SDL_RenderClear(renderer);
        SDL_RenderTexture(renderer, texture, NULL, NULL);
        SDL_RenderPresent(renderer);
    }

    free(draw_buf);
    free(recv_frame_buf);
    SDL_DestroyTexture(texture);
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();

    return 0;
}

void copy_convert(uint8_t* dest_rgb24, uint8_t* src_rgb16){
    int b24 = 0;
    int b16 = 0;
    for(int i = 0; i < SWIDTH * SHEIGHT; i++){
        //R
        dest_rgb24[b24] = (src_rgb16[b16] & 0b11111000) >> 3;

        //G
        dest_rgb24[b24+1] = ((src_rgb16[b16] & 0b00000111) << 3)  +  ((src_rgb16[b16+1] & 0b11100000) >> 5);

        //B
        dest_rgb24[b24+2] = (src_rgb16[b16+1] & 0b00011111);
        
        b24 += 3;
        b16 += 2;
    }
}