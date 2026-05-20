#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <io.h>
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>

#include <SDL2/SDL.h>



// Link against the Winsock library (used by MSVC)
#pragma comment(lib, "ws2_32.lib")

#define PORT 5000
#define WIDTH 320
#define HEIGHT 240
#define BPP 2 // 16-bit RGB565 is 2 bytes per pixel
#define FRAME_SIZE (WIDTH * HEIGHT * BPP)
#define BUFFER_SIZE 65536 // Max UDP datagram size

#define PACKET_SIZE 1202
#define PACKETS_PER_FRAME 128
#define FRAME_TOUT_MS 750

typedef unsigned long long ull;

ull curr_ms(){
    return GetTickCount64();
}

int main(int argc, char** argv) {
    (void)argc; (void)argv;

    uint32_t MAGIC = 0xDEADBEEF;

    //Socket setup
    WSADATA wsaData;
    SOCKET sockfd;
    struct sockaddr_in servaddr;
    uint8_t buffer[BUFFER_SIZE];
    uint32_t sync_window = 0;
    long long frame_bytes_read = 0;
    int in_frame = 0;

    // Initialize Winsock
    if (WSAStartup(MAKEWORD(2, 2), &wsaData) != 0) {
        fprintf(stderr, "WSAStartup failed.\n");
        return 1;
    }

    sockfd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if (sockfd == INVALID_SOCKET) {
        fprintf(stderr, "Socket creation failed with error: %d\n", WSAGetLastError());
        WSACleanup();
        return 1;
    }

    memset(&servaddr, 0, sizeof(servaddr));
    servaddr.sin_family = AF_INET;
    servaddr.sin_addr.s_addr = INADDR_ANY;
    servaddr.sin_port = htons(PORT);

    u_long mode = 1;
    ioctlsocket(sockfd, FIONBIO, &mode);

    if (bind(sockfd, (const struct sockaddr *)&servaddr, sizeof(servaddr)) == SOCKET_ERROR) {
        fprintf(stderr, "Bind failed with error: %d\n", WSAGetLastError());
        closesocket(sockfd);
        WSACleanup();
        return 1;
    }

    if (SDL_Init(SDL_INIT_VIDEO) != 0) {
        fprintf(stderr, "SDL_Init failed: %s\n", SDL_GetError());
        return 1;
    }

    SDL_Window* window = SDL_CreateWindow(
        "RGB565 Stream Viewer",
        SDL_WINDOWPOS_CENTERED,
        SDL_WINDOWPOS_CENTERED,
        WIDTH * 2,
        HEIGHT * 2,
        SDL_WINDOW_SHOWN
    );

    SDL_Renderer* renderer = SDL_CreateRenderer(window, -1, 0);

    SDL_Texture* texture = SDL_CreateTexture(
        renderer,
        SDL_PIXELFORMAT_RGB565,
        SDL_TEXTUREACCESS_STREAMING,
        WIDTH,
        HEIGHT
    );

    uint16_t* draw_buf = (uint16_t*)malloc(WIDTH * HEIGHT * sizeof(uint16_t));
    uint16_t* recv_frame_buf = (uint16_t*)malloc(WIDTH * HEIGHT * sizeof(uint16_t));

    size_t frame_bytes = WIDTH * HEIGHT * sizeof(uint16_t);

    SDL_Event e;
    int running = 1;

    ull last_frame_time = 0;

    while (running) {
        //Receive data
        int n = recvfrom(sockfd, (char *)buffer, BUFFER_SIZE, 0, NULL, NULL);
        
        if(n == SOCKET_ERROR)
            goto render_frame;
        if(n != PACKET_SIZE){
            printf("RECEIVED PACKET OF SIZE %d\n",n);
            goto render_frame;
        }

        uint16_t seq_num = buffer[1];
        if((uint8_t*)recv_frame_buf + (seq_num * (PACKET_SIZE-2)) + PACKET_SIZE-2 > (uint8_t*)recv_frame_buf + WIDTH * HEIGHT * sizeof(uint16_t)){
            printf("seq_num - %d\n",seq_num);
            continue;
        }
        memcpy((uint8_t*)recv_frame_buf + (seq_num * (PACKET_SIZE-2)), buffer+2, PACKET_SIZE-2);

        if(seq_num == PACKETS_PER_FRAME-1){
            //printf("4");

            memcpy((uint8_t*)draw_buf, (uint8_t*)recv_frame_buf, FRAME_SIZE);
            last_frame_time = curr_ms();
        } else if(curr_ms() - last_frame_time >= FRAME_TOUT_MS){
            printf("FRAME TIMEOUT\n");
            memcpy((uint8_t*)draw_buf, (uint8_t*)recv_frame_buf, FRAME_SIZE);
            last_frame_time = curr_ms();
        }


        render_frame:
        // Handle window events
        while (SDL_PollEvent(&e)) {
            if (e.type == SDL_QUIT) {
                running = 0;
            }
        }

        //Render new frame
        SDL_UpdateTexture(texture, NULL, draw_buf, WIDTH * sizeof(uint16_t));

        SDL_RenderClear(renderer);
        SDL_RenderCopy(renderer, texture, NULL, NULL);
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