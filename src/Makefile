recv: recvvideo.c
	gcc recvvideo.c -o recv -Wall -Wextra -O2 $$(pkg-config --cflags --libs sdl3)

send: sendvideo.cpp
	echo "TARGET UNDEFINED IN MAKEFILE"

test: vidtest.cpp
	g++ vidtest.cpp -o test -Wall -Wextra $$(pkg-config --cflags --libs opencv4 sdl3)

clean:
	rm -f recv test