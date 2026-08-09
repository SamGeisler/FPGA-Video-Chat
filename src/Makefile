recv: recvvideo.c
	gcc recvvideo.c -o recv -Wall -Wextra -O2 $$(pkg-config --cflags --libs sdl3)

send: sendvideo.c
	gcc -O3 -Wall sendvideo.c -o send

test: vidtest.cpp
	g++ vidtest.cpp -o test -Wall -Wextra $$(pkg-config --cflags --libs opencv4 sdl3)

clean:
	rm -f recv test