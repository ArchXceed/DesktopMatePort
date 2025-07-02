#ifndef IMAGE_UTILS_H
#define IMAGE_UTILS_H

unsigned char* decode_jpeg(unsigned char* buffer, long size, int* out_width, int* out_height);
unsigned char* convert_rgb_to_rgb32(unsigned char* rgb, int width, int height, int threshold);

typedef struct {
    int x, y, width, height;
} Rect;

Rect detect_alpha_bounds_argb32(unsigned char* data, int width, int height);

#endif