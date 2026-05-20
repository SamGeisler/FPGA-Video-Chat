// udp_hex_dump.c
// Compile with: cl udp_hex_dump.c ws2_32.lib

#include <winsock2.h>
#include <ws2tcpip.h>
#include <stdio.h>

#pragma comment(lib, "Ws2_32.lib")

#define BUF_SIZE 2048

int main() {
    WSADATA wsa;
    SOCKET sock;
    struct sockaddr_in addr, src_addr;
    int src_len = sizeof(src_addr);
    char buffer[BUF_SIZE];
    int recv_len;

    const char *bind_ip = "192.168.1.114"; // change to specific IP if needed
    unsigned short bind_port = 5000; // change to desired port

    // Initialize WinSock
    if (WSAStartup(MAKEWORD(2,2), &wsa) != 0) {
        printf("WSAStartup failed\n");
        return 1;
    }

    // Create UDP socket
    sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if (sock == INVALID_SOCKET) {
        printf("socket() failed\n");
        WSACleanup();
        return 1;
    }

    // Bind to IP and port
    addr.sin_family = AF_INET;
    addr.sin_port = htons(bind_port);
    inet_pton(AF_INET, bind_ip, &addr.sin_addr);

    if (bind(sock, (struct sockaddr*)&addr, sizeof(addr)) == SOCKET_ERROR) {
        printf("bind() failed\n");
        closesocket(sock);
        WSACleanup();
        return 1;
    }

    printf("Listening on %s:%d...\n", bind_ip, bind_port);

    while (1) {
        recv_len = recvfrom(sock, buffer, BUF_SIZE, 0,
                            (struct sockaddr*)&src_addr, &src_len);

        if (recv_len == SOCKET_ERROR) {
            printf("recvfrom() failed\n");
            break;
        }

        printf("Received %d bytes from %s:%d\n",
               recv_len,
               inet_ntoa(src_addr.sin_addr),
               ntohs(src_addr.sin_port));

        // Hex dump
        for (int i = 0; i < recv_len; i++) {
            printf("%02X ", (unsigned char)buffer[i]);
            if ((i + 1) % 16 == 0)
                printf("\n");
        }
        printf("\n\n");
    }

    closesocket(sock);
    WSACleanup();
    return 0;
}