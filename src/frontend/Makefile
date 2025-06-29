CC = gcc
CFLAGS = -Wall -g -D_GNU_SOURCE `pkg-config --cflags x11 cairo libjpeg` -Iinclude -I.
LDFLAGS = `pkg-config --libs x11 cairo libjpeg` -lpthread

SRC = src/app_state.c src/event_queue.c src/hyprctl.c src/image_utils.c src/overlay_wayland.c src/wayland_utils.c $(PROTOCOLS)

all: overlay_wayland

overlay_wayland: $(SRC)
	$(CC) $(CFLAGS) -o $@ $(SRC) $(LDFLAGS)


clean:
	rm -f overlay_wayland *.o src/*.o xdg-shell-client-protocol.* wlr-layer-shell-unstable-v1-client-protocol.*

.PHONY: all clean