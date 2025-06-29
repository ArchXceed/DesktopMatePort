#ifndef APP_STATE_H
#define APP_STATE_H

typedef struct {
    unsigned char* cropped_rgb32;
} AppState;

extern int window_x_absolute;
extern int window_y_absolute;
extern AppState app;

#endif