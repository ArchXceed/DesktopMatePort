#include "hyprctl.h"
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#define SCREEN_OFFSET 0


static void run_cmd(const char* cmd) {
    int ret = system(cmd);
    (void)ret;
}

void* async_hyprctl_thread(void* arg) {
    WindowMoveResizeParams* params = (WindowMoveResizeParams*)arg;
 char cmd[512];
    
        snprintf(cmd, sizeof(cmd),
            "(hyprctl dispatch movewindowpixel 'exact %d %d,address:0x%s' &) && "
            "(hyprctl dispatch resizewindowpixel 'exact %d %d,address:0x%s' &)",
            params->x + SCREEN_OFFSET, params->y, params->address,
            params->w, params->h, params->address
        );
        run_cmd(cmd);

    free(params);
    return NULL;
}
