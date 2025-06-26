#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xatom.h>
#include <cairo/cairo.h>
#include <cairo/cairo-xlib.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <stdbool.h>
#include "event_queue.h"
#include "app_state.h"
#include "overlay_wayland.h"

#define EVENT_MOUSE_MOVE 0
#define EVENT_CLICK_DOWN 1
#define EVENT_CLICK_UP 2

static bool button2_toggled = false;
int waiting_for_configure = 0;
Display *display = NULL;
Window window;
int screen;
cairo_surface_t *cairo_surface = NULL;
cairo_t *cr = NULL;
int width = 800;
int height = 600;
pthread_mutex_t offscreen_mutex = PTHREAD_MUTEX_INITIALIZER;
XVisualInfo vinfo;
bool frame_locked = false;

void draw_image(unsigned char *img_data, int img_width, int img_height, int original_pos_x, int original_pos_y, int w, int h, bool size_changes);

void force_redraw()
{
    XEvent ev;
    memset(&ev, 0, sizeof(ev));
    ev.type = Expose;
    ev.xexpose.window = window;
    XSendEvent(display, window, False, ExposureMask, &ev);
    XFlush(display);
}

void draw_image(unsigned char *img_data, int img_width, int img_height, int original_pos_x, int original_pos_y, int w, int h, bool size_changes)
{
    pthread_mutex_lock(&offscreen_mutex);

    if (cr)
    {
        cairo_destroy(cr);
        cr = NULL;
    }
    if (cairo_surface)
    {
        cairo_surface_destroy(cairo_surface);
        cairo_surface = NULL;
    }

    cairo_surface = cairo_xlib_surface_create(display, window, vinfo.visual, w, h);
    if (!cairo_surface)
    {
        pthread_mutex_unlock(&offscreen_mutex);
        return;
    }
    cr = cairo_create(cairo_surface);
    if (!cr)
    {
        cairo_surface_destroy(cairo_surface);
        pthread_mutex_unlock(&offscreen_mutex);
        return;
    }

    if (!img_data || img_width <= 0 || img_height <= 0)
    {
        pthread_mutex_unlock(&offscreen_mutex);
        return;
    }

    cairo_surface_t *image_surface = cairo_image_surface_create_for_data(
        img_data, CAIRO_FORMAT_ARGB32, img_width, img_height, img_width * 4);

    cairo_save(cr);
    cairo_set_operator(cr, CAIRO_OPERATOR_CLEAR);
    cairo_paint(cr);
    cairo_restore(cr);

    cairo_save(cr);
    cairo_set_operator(cr, CAIRO_OPERATOR_OVER);
    cairo_set_source_surface(cr, image_surface, 0, 0);
    cairo_paint(cr);
    cairo_restore(cr);

    cairo_surface_destroy(image_surface);
    cairo_surface_flush(cairo_surface);
    XFlush(display);

    pthread_mutex_unlock(&offscreen_mutex);
}
void setup_window()
{
    display = XOpenDisplay(NULL);
    if (!display)
    {
        fprintf(stderr, "Failed to open X display\n");
        exit(1);
    }
    screen = DefaultScreen(display);

    
    if (!XMatchVisualInfo(display, screen, 32, TrueColor, &vinfo))
    {
        fprintf(stderr, "No 32-bit TrueColor visual found!\n");
        exit(1);
    }

    XSetWindowAttributes attrs;
    attrs.colormap = XCreateColormap(display, RootWindow(display, screen), vinfo.visual, AllocNone);
    attrs.background_pixel = 0;
    attrs.border_pixel = 0;

    window = XCreateWindow(
        display, RootWindow(display, screen),
        0, 0, width, height, 0,
        vinfo.depth, InputOutput, vinfo.visual,
        CWColormap | CWBackPixel | CWBorderPixel, &attrs);
    long event_mask = ExposureMask | ButtonPressMask | ButtonReleaseMask | PointerMotionMask | StructureNotifyMask;
    XSelectInput(display, window, event_mask);
    XStoreName(display, window, "Overlay");
    Atom wm_class = XInternAtom(display, "WM_CLASS", False);

    XStoreName(display, window, "Overlay");

    
    const char wm_class_name[] = "Overlay\0Overlay";
    
    Atom net_wm_state = XInternAtom(display, "_NET_WM_STATE", False);
    Atom net_wm_state_above = XInternAtom(display, "_NET_WM_STATE_ABOVE", False);
    XChangeProperty(display, window, net_wm_state, XA_ATOM, 32, PropModeReplace,
                    (unsigned char *)&net_wm_state_above, 1);

    
    struct
    {
        unsigned long flags;
        unsigned long functions;
        unsigned long decorations;
        long input_mode;
        unsigned long status;
    } motif_hints = {2, 0, 0, 0, 0};
    Atom property = XInternAtom(display, "_MOTIF_WM_HINTS", False);
    XChangeProperty(display, window, property, property, 32, PropModeReplace, (unsigned char *)&motif_hints, 5);
    Atom net_wm_window_type = XInternAtom(display, "_NET_WM_WINDOW_TYPE", False);
    Atom net_wm_window_type_dialog = XInternAtom(display, "_NET_WM_WINDOW_TYPE_DIALOG", False);
    XChangeProperty(display, window, net_wm_window_type, XA_ATOM, 32, PropModeReplace,
                    (unsigned char *)&net_wm_window_type_dialog, 1);
    XMapWindow(display, window);

    cairo_surface = cairo_xlib_surface_create(
        display, window,
        vinfo.visual,
        width, height);
    cr = cairo_create(cairo_surface);
}

void *dispatch_thread(void *arg)
{
    XEvent event;
    while (1)
    {
        XNextEvent(display, &event);
        switch (event.type)
        {
        case Expose:
            
            XFlush(display);
            break;
        case MotionNotify:
        {
            
            InputEvent *ev = malloc(sizeof(InputEvent));
            ev->type = EVENT_MOUSE_MOVE;
            int x, y;
            Window child;
            XWindowAttributes xwa;
            Window root_window = RootWindow(display, screen);
            XTranslateCoordinates(display, window, root_window, 0, 0, &x, &y, &child);
            XGetWindowAttributes(display, window, &xwa);
            ev->x = x - screen_x_offset + event.xbutton.x;
            ev->y = y - screen_y_offset + event.xbutton.y;
            ev->button = 0;
            ev->next = NULL;
            enqueue(&g_event_queue, ev);
            break;
        }
        case ButtonPress:
        {            
                InputEvent *ev = malloc(sizeof(InputEvent));
                ev->type = EVENT_CLICK_DOWN;
                int x, y;
                Window child;
                XWindowAttributes xwa;
                Window root_window = RootWindow(display, screen);
                XTranslateCoordinates(display, window, root_window, 0, 0, &x, &y, &child);
                XGetWindowAttributes(display, window, &xwa);
		printf("Window coordinates: (%d, %d)\n", x, y);

                ev->x = x - screen_x_offset + event.xbutton.x;
		ev->y = y - screen_y_offset + event.xbutton.y;
		printf("MousePos: (%d, %d)\n", event.xbutton.x, event.xbutton.y);
                ev->button = event.xbutton.button;

                ev->next = NULL;
                enqueue(&g_event_queue, ev);
            break;
        }
        case ButtonRelease:
        {
            InputEvent *ev = malloc(sizeof(InputEvent));
            ev->type = EVENT_CLICK_UP;
            int x, y;
            Window child;
            XWindowAttributes xwa;
            Window root_window = RootWindow(display, screen);
            XTranslateCoordinates(display, window, root_window, 0, 0, &x, &y, &child);
            XGetWindowAttributes(display, window, &xwa);
            ev->x = x - screen_x_offset + event.xbutton.x;
            ev->y = y - screen_y_offset + event.xbutton.y;
            ev->button = event.xbutton.button;

            ev->next = NULL;
            enqueue(&g_event_queue, ev);
            break;
        }
        case ConfigureNotify:
            
            width = event.xconfigure.width;
            height = event.xconfigure.height;
            usleep(1000);
            printf("Window resized to %dx%d at (%d, %d)\n", width, height, window_x_absolute, window_y_absolute);
            frame_locked = false;
            
            
            break;
        }
    }
    return NULL;
}
