#ifndef WAYLAND_UTILS_H
#define WAYLAND_UTILS_H

#include <wayland-client.h>
#include <pthread.h>
#include <stdbool.h>

void force_redraw();
void setup_window();
void draw_image(unsigned char* img_data, int img_width, int img_height, int original_pos_x, int original_pos_y, int w, int h, bool size_changes);
void* dispatch_thread(void* arg);

extern volatile int waiting_for_configure;
extern struct wl_display *display;
extern int width, height;
extern int last_x, last_y, last_w, last_h;
extern pthread_mutex_t offscreen_mutex;
extern bool frame_ready;
extern bool frame_locked;

#endif
