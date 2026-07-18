#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <iostream>

#include <opencv2/opencv.hpp>
#include <SDL3/SDL.h>

//Higher resolutions are not supported for raw data
#define WIDTH_DEFAULT 640
#define HEIGHT_DEFAULT 480

int WIDTH, HEIGHT;

int init_SDL(SDL_Window** window, SDL_Renderer** renderer, SDL_Texture** texture){
    if (SDL_Init(SDL_INIT_VIDEO) < 0) {
        fprintf(stderr, "Could not initialize SDL: %s\n", SDL_GetError());
        return -1;
    }

    *window = SDL_CreateWindow("Video", WIDTH, HEIGHT, 0); 

    *renderer = SDL_CreateRenderer(*window, NULL);

    *texture = SDL_CreateTexture(
        *renderer,
        SDL_PIXELFORMAT_RGB24,        // Expecting standard RGB bytes
        SDL_TEXTUREACCESS_STREAMING,  // Optimized for frequent updates
        WIDTH, HEIGHT
    );
    
    SDL_RenderTexture(*renderer, *texture, NULL, NULL);

    return 0;
}

int close_SDL(SDL_Window* window, SDL_Renderer* renderer, SDL_Texture* texture){
    SDL_DestroyTexture(texture);
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();

    return 0;
}

int main(int argc, char** argv) {
    if(argc == 3){
        WIDTH = atoi(argv[1]);
        HEIGHT = atoi(argv[2]);
    } else {
        WIDTH = WIDTH_DEFAULT;
        HEIGHT = HEIGHT_DEFAULT;
    }

    std::cout << "OpenCV Version: " << CV_VERSION << std::endl;

    cv::VideoCapture* cap = new cv::VideoCapture(0, cv::CAP_V4L2);
    if(!cap || !cap->isOpened()){
        fprintf(stderr,"Failed to open video capture.\n");
        return -1;
    }
    cap->set(cv::CAP_PROP_FRAME_WIDTH, WIDTH);
    cap->set(cv::CAP_PROP_FRAME_HEIGHT, HEIGHT);

    int actual_width = cap->get(cv::CAP_PROP_FRAME_WIDTH);
    int actual_height = cap->get(cv::CAP_PROP_FRAME_HEIGHT);
    printf("Configured resolution: %dx%d - Attempted from %dx%d\n", actual_width, actual_height, WIDTH, HEIGHT);


    cv::Mat* frame_bgr = new cv::Mat();
    cv::Mat* frame_rgb = new cv::Mat();

    if(!frame_bgr || !frame_rgb){
        fprintf(stderr, "Failed to allocate frame buffers.\n");
        return -1;
    }

    SDL_Window* window;
    SDL_Renderer* renderer;
    SDL_Texture* texture;

    if(init_SDL(&window, &renderer, &texture)){
        fprintf(stderr, "Failed to init SDL.\n");
        return -1;
    }

    bool running = true;
    SDL_Event event;

    // 5. The Application Loop
    while (running) {
        // Handle window close events
        while (SDL_PollEvent(&event)) {
            if (event.type == SDL_EVENT_QUIT) {
                running = false;
            }
        }

        //Capture
        *cap >> *frame_bgr;
        cv::cvtColor(*frame_bgr, *frame_rgb, cv::COLOR_BGR2RGB);

        //Render
        SDL_UpdateTexture(texture, NULL, frame_rgb->data, frame_rgb->step[0]);
        SDL_RenderClear(renderer);
        SDL_RenderTexture(renderer, texture, NULL, NULL);
        SDL_RenderPresent(renderer);
    }

    close_SDL(window, renderer, texture);

    delete cap;
    delete frame_bgr;
    delete frame_rgb;

    return 0;
}