#include "image_utils.h"
#include <stdio.h>
#include <stdlib.h>
#include <jpeglib.h>
#include <setjmp.h>
#include <string.h>
struct my_error_mgr {
    struct jpeg_error_mgr pub;
    jmp_buf setjmp_buffer;
};
typedef struct my_error_mgr* my_error_ptr;

static void my_error_exit(j_common_ptr cinfo) {
    my_error_ptr myerr = (my_error_ptr)cinfo->err;
    (*cinfo->err->output_message)(cinfo);
    longjmp(myerr->setjmp_buffer, 1);
}

unsigned char* decode_jpeg(unsigned char* buffer, long size, int* out_width, int* out_height) {
    struct jpeg_decompress_struct cinfo;
    struct my_error_mgr jerr;
    JSAMPARRAY buffer_array;
    unsigned char* output = NULL;

    cinfo.err = jpeg_std_error(&jerr.pub);
    jerr.pub.error_exit = my_error_exit;

    if (setjmp(jerr.setjmp_buffer)) {
        jpeg_destroy_decompress(&cinfo);
        return NULL;
    }

    jpeg_create_decompress(&cinfo);
    jpeg_mem_src(&cinfo, buffer, size);
    jpeg_read_header(&cinfo, TRUE);
    jpeg_start_decompress(&cinfo);

    *out_width = cinfo.output_width;
    *out_height = cinfo.output_height;
    output = malloc(cinfo.output_width * cinfo.output_height * cinfo.output_components);

    buffer_array = (*cinfo.mem->alloc_sarray)((j_common_ptr)&cinfo, JPOOL_IMAGE, cinfo.output_width * cinfo.output_components, 1);
    unsigned char* p = output;

    while (cinfo.output_scanline < cinfo.output_height) {
        jpeg_read_scanlines(&cinfo, buffer_array, 1);
        memcpy(p, buffer_array[0], cinfo.output_width * cinfo.output_components);
        p += cinfo.output_width * cinfo.output_components;
    }

    jpeg_finish_decompress(&cinfo);
    jpeg_destroy_decompress(&cinfo);

    return output;
}

unsigned char* convert_rgb_to_rgb32(unsigned char* rgb, int width, int height, int threshold) {
    int pixels = width * height;
    unsigned char* out = malloc(pixels * 4);
    for (int i = 0; i < pixels; i++) {
        unsigned char r = rgb[i * 3 + 0];
        unsigned char g = rgb[i * 3 + 1];
        unsigned char b = rgb[i * 3 + 2];

        int dr = r - 0;
        int dg = g - 0;
        int db = b - 0;
        int dist_sq = dr*dr + dg*dg + db*db;

        unsigned char alpha = (dist_sq < threshold * threshold) ? 0 : 255;
        out[i * 4 + 0] = b;
        out[i * 4 + 1] = g;
        out[i * 4 + 2] = r;
        out[i * 4 + 3] = alpha;
    }
    return out;
}

Rect detect_alpha_bounds_argb32(unsigned char* data, int width, int height) {
    int min_x = width, min_y = height, max_x = -1, max_y = -1;
    int stride = width * 4;

    for (int y = 0; y < height; y++) {
        unsigned char* row = data + y * stride;
        for (int x = 0; x < width; x++) {
            unsigned char alpha = row[x * 4 + 3];
            if (alpha > 0) {
                if (x < min_x) min_x = x;
                if (x > max_x) max_x = x;
                if (y < min_y) min_y = y;
                if (y > max_y) max_y = y;
            }
        }
    }

    if (max_x < min_x || max_y < min_y) {
        return (Rect){0, 0, 0, 0};
    }

    return (Rect){min_x, min_y, max_x - min_x + 1, max_y - min_y + 1};
}