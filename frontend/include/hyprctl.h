#ifndef HYPRCTL_H
#define HYPRCTL_H

typedef struct {
    int x, y, w, h;
    char address[32];
} WindowMoveResizeParams;

void* async_hyprctl_thread(void* arg);

#endif