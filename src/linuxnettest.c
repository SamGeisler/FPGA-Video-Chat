#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <arpa/inet.h>

#define DEST_IP "169.254.80.58"
#define DEST_PORT 8080

int main() {
    int sockfd;
    struct sockaddr_in dest_addr;
    const char *message = "dummy packet";

    // Create UDP socket
    sockfd = socket(AF_INET, SOCK_DGRAM, 0);

    memset(&dest_addr, 0, sizeof(dest_addr));
    dest_addr.sin_family = AF_INET;
    dest_addr.sin_port = htons(DEST_PORT);
    inet_pton(AF_INET, DEST_IP, &dest_addr.sin_addr);

    // Send loop
    while (1) {
        sendto(sockfd, message, strlen(message), 0, 
               (struct sockaddr*)&dest_addr, sizeof(dest_addr));
        
        printf("Packet sent\n");
        sleep(1);
    }

    close(sockfd);
    return 0;
}