#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <winsock2.h>
/* Requires downloading escapi.h and escapi.cpp */
#include "escapi.h" 

#pragma comment(lib, "ws2_32.lib")

#define DEST_IP "169.254.80.11"
#define DEST_PORT 5000
#define WIDTH 320
#define HEIGHT 240

#define PACKETS_PER_FRAME 128
#define PACKET_PERIOD_MS 10
#define PACKET_SIZE 1202
#define PIXELS_PER_PACKET (PACKET_SIZE/2 - 1)

typedef unsigned long long ull;

ull curr_ms(){
    return GetTickCount64();
}
ull last_packet_ts;

int main() {
    WSADATA wsaData;
    if (WSAStartup(MAKEWORD(2, 2), &wsaData) != 0) return 1;

    SOCKET udpSocket = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    struct sockaddr_in destAddr;
    destAddr.sin_family = AF_INET;
    destAddr.sin_port = htons(DEST_PORT);
    destAddr.sin_addr.s_addr = inet_addr(DEST_IP);

    if (setupESCAPI() == 0) {
        WSACleanup();
        return 1;
    }

    struct SimpleCapParams capture;
    capture.mWidth = WIDTH;
    capture.mHeight = HEIGHT;
    capture.mTargetBuf = (int *)malloc(WIDTH * HEIGHT * sizeof(int));

    /* Initialize the first capture device (index 0) */
    if (initCapture(0, &capture) == 0) {
        WSACleanup();
        return 1;
    }

    uint16_t *rgb444Buf = (uint16_t *)malloc(WIDTH * HEIGHT * sizeof(uint16_t));
    int totalBytes = WIDTH * HEIGHT * sizeof(uint16_t);



    while(1){
        /* Request a frame */
        doCapture(0);
        while (isCaptureDone(0) == 0) {
            Sleep(1);
        }

        /* Convert 32-bit BGRA buffer to 16-bit RGB565 */
        for (int i = 0; i < WIDTH * HEIGHT; i++) {
            int bgra = capture.mTargetBuf[i];
           // printf("0x%x   ",bgra);
            
            // Extract 8-bit components
            uint8_t b = (bgra & 0x000000FF);
            //uint8_t b = 0;
            uint8_t g = (bgra & 0x0000FF00) >> 8;
            //uint8_t g = 0;
            uint8_t r = (bgra & 0x00FF0000) >> 16;

            // Downsample to 4 bits (keep the most significant 4 bits)
            uint16_t b4 = (b >> 4);
            uint16_t g4 = (g >> 4);
            uint16_t r4 = (r >> 4);

            //printf("%x ", r4);
            //uint16_t r4 = 0x0004;
            // Pack into a single 16-bit word: 0000 RRRR GGGG BBBB
            rgb444Buf[i] = (r4 << 8) | (g4 << 4) | b4;
            //rgb444Buf[i] = 0xF000;
        }

        /* Fragment the frame into safe UDP chunks and transmit */
        uint8_t *ptr = (uint8_t *)rgb444Buf;

        int pi = 0;
        int pj = 0;

        for(uint16_t p = 0; p < PACKETS_PER_FRAME; p++){
            uint16_t pack_buf[PACKET_SIZE/2];
            for(int i = 0; i<PACKET_SIZE/2; i++)
                pack_buf[i] = 0;
            ((uint8_t*)pack_buf)[0] = p%256;
            ((uint8_t*)pack_buf)[1] = 0;
            

            memcpy((uint8_t*)pack_buf + 2, (uint8_t*)(rgb444Buf + (p*PIXELS_PER_PACKET)), PIXELS_PER_PACKET*2);

            uint8_t*d = (uint8_t*)pack_buf + 2;
            uint8_t* s = (uint8_t*)(rgb444Buf + (p*PIXELS_PER_PACKET));
            for(int i = 0; i < PIXELS_PER_PACKET*2; i++){
                d[i] = s[i];
            }

            // while(curr_ms() - last_packet_ts < PACKET_PERIOD_MS)
            //     continue;
            sendto(udpSocket, (char *)pack_buf, PACKET_SIZE, 0, (struct sockaddr*)&destAddr, sizeof(destAddr));
            last_packet_ts = curr_ms();
        }
    }

    deinitCapture(0);
    free(capture.mTargetBuf);
    free(rgb444Buf);
    closesocket(udpSocket);
    WSACleanup();
    return 0;
}