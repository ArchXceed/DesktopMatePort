#include "overlay_wayland.h"
#include "app_state.h"
#include "event_queue.h"
#include "hyprctl.h"
#include "image_utils.h"
#include "wayland_utils.h"
#include <arpa/inet.h>
#include <errno.h>
#include <netdb.h>
#include <netinet/in.h>
#include <pthread.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <unistd.h>


#define SERVER_IP "127.0.0.1"
#define SERVER_PORT 4089
#define MAX_UDP_PACKET 65507
#define MAX_CHUNKS 256

int last_x = 0;
int last_y = 0;
int last_w = 0;
int last_h = 0;
bool frame_ready = false;
int screen_x_offset = 0;
int screen_y_offset = 0;

typedef struct
{
  unsigned char *data;
  size_t size;
  bool received;
} Chunk;

extern int move_init;
typedef struct
{
  void *arg;
  const char *desktop_env;
} UdpReceiveThreadArgs;

int pad_left = 150;
int pad_right = 50;
int pad_top = 150;
int pad_bottom = 50;
int round_to = 150;

void load_or_create_config(const char *path) {
    FILE *file = fopen(path, "r");
    if (!file) {
        file = fopen(path, "w");
        if (!file) {
            perror("Failed to create config");
            exit(1);
        }
        fprintf(file, "pad_left=150\n");
        fprintf(file, "pad_right=50\n");
        fprintf(file, "pad_top=150\n");
        fprintf(file, "pad_bottom=50\n");
        fprintf(file, "round_to=150\n");
        fclose(file);
        return;
    }

    char line[256];
    while (fgets(line, sizeof(line), file)) {
        if (strncmp(line, "pad_left=", 9) == 0)
            pad_left = atoi(line + 9);
        else if (strncmp(line, "pad_right=", 10) == 0)
            pad_right = atoi(line + 10);
        else if (strncmp(line, "pad_top=", 8) == 0)
            pad_top = atoi(line + 8);
        else if (strncmp(line, "pad_bottom=", 11) == 0)
            pad_bottom = atoi(line + 11);
        else if (strncmp(line, "round_to=", 9) == 0)
            round_to = atoi(line + 9);
    }

    fclose(file);
}


void *udp_receive_thread(void *vargs)
{
  UdpReceiveThreadArgs *args = (UdpReceiveThreadArgs *)vargs;
  void *arg = args->arg;
  const char *desktop_env = args->desktop_env;
  free(args);
  int sock = socket(AF_INET, SOCK_DGRAM, 0);
  if (sock < 0)
  {
    perror("socket");
    exit(1);
  }

  struct sockaddr_in client_addr;
  client_addr.sin_family = AF_INET;
  client_addr.sin_addr.s_addr = INADDR_ANY;
  client_addr.sin_port = htons(SERVER_PORT + 5);
  if (bind(sock, (struct sockaddr *)&client_addr, sizeof(client_addr)) < 0)
  {
    perror("bind");
    exit(1);
  }

  struct sockaddr_in servaddr;
  servaddr.sin_family = AF_INET;
  servaddr.sin_port = htons(SERVER_PORT);
  inet_pton(AF_INET, SERVER_IP, &servaddr.sin_addr);

  const char *msg = "connect";
  sendto(sock, msg, strlen(msg), 0, (struct sockaddr *)&servaddr,
         sizeof(servaddr));

  unsigned char buffer[MAX_UDP_PACKET];
  Chunk chunks[MAX_CHUNKS];
  int expected_total_chunks = 0;
  int received_chunks_count = 0;

  for (int i = 0; i < MAX_CHUNKS; i++)
  {
    chunks[i].data = NULL;
    chunks[i].size = 0;
    chunks[i].received = false;
  }

  while (1)
  {
    ssize_t recvlen = recv(sock, buffer, MAX_UDP_PACKET, 0);
    if (recvlen < 20)
      continue;

    uint16_t chunk_idx = ntohs(*(uint16_t *)(buffer));
    uint16_t total_chunks = ntohs(*(uint16_t *)(buffer + 2));

    if (total_chunks > MAX_CHUNKS)
    {
      fprintf(stderr, "Too many chunks %d\n", total_chunks);
      continue;
    }

    if (expected_total_chunks != total_chunks)
    {
      for (int i = 0; i < expected_total_chunks; i++)
      {
        if (chunks[i].data)
          free(chunks[i].data);
        chunks[i].data = NULL;
        chunks[i].size = 0;
        chunks[i].received = false;
      }
      expected_total_chunks = total_chunks;
      received_chunks_count = 0;
    }

    if (!chunks[chunk_idx].received)
    {
      size_t chunk_data_size = recvlen - 4;
      chunks[chunk_idx].data = malloc(chunk_data_size);
      memcpy(chunks[chunk_idx].data, buffer + 4, chunk_data_size);
      chunks[chunk_idx].size = chunk_data_size;
      chunks[chunk_idx].received = true;
      received_chunks_count++;
    }

    if (received_chunks_count == expected_total_chunks)
    {
      size_t full_size = 0;
      for (int i = 0; i < expected_total_chunks; i++)
        full_size += chunks[i].size;

      unsigned char *full_data = malloc(full_size);
      size_t offset = 0;
      for (int i = 0; i < expected_total_chunks; i++)
      {
        memcpy(full_data + offset, chunks[i].data, chunks[i].size);
        offset += chunks[i].size;
        free(chunks[i].data);
        chunks[i].data = NULL;
        chunks[i].size = 0;
        chunks[i].received = false;
      }

      expected_total_chunks = 0;
      received_chunks_count = 0;

      int32_t net_pos_x, net_pos_y, net_w, net_h;
      memcpy(&net_pos_x, full_data, 4);
      memcpy(&net_pos_y, full_data + 4, 4);
      memcpy(&net_w, full_data + 8, 4);
      memcpy(&net_h, full_data + 12, 4);

      int pos_x = ntohl(net_pos_x) + screen_x_offset;
      int pos_y = ntohl(net_pos_y) + screen_y_offset;
      int w = ntohl(net_w);
      int h = ntohl(net_h);

      unsigned char *jpeg_data = full_data + 16;
      size_t jpeg_size = full_size - 16;

      int img_w, img_h;
      unsigned char *rgb = decode_jpeg(jpeg_data, jpeg_size, &img_w, &img_h);
      if (rgb)
      {
        unsigned char *rgb32 = convert_rgb_to_rgb32(rgb, img_w, img_h, 30);
        if (rgb32)
        {

          Rect crop = detect_alpha_bounds_argb32(rgb32, img_w, img_h);
          if (crop.width == 0 || crop.height == 0)
          {
            crop.x = 0;
            crop.y = 0;
            crop.width = img_w;
            crop.height = img_h;
          }

          int orig_x = crop.x;
          int orig_y = crop.y;
          int orig_w = crop.width;
          int orig_h = crop.height;

          
          int pad_left = 150;
          int pad_right = 50;
          int pad_top = 150;
          int pad_bottom = 50;

          int round_to = 150;


	  int rounded_x = ((orig_x - pad_left + (round_to - 1)) / round_to) * round_to;
          int rounded_y = ((orig_y - pad_top + (round_to - 1)) / round_to) * round_to;
          int right = orig_x + orig_w + pad_right;
          int bottom = orig_y + orig_h + pad_bottom;

          
          if (rounded_x < 0)
            rounded_x = 0;
          if (rounded_y < 0)
            rounded_y = 0;
          if (right > img_w)
            right = img_w;
          if (bottom > img_h)
            bottom = img_h;

          int rounded_w = ((right - rounded_x + (round_to - 1)) / round_to) * round_to;
          int rounded_h = ((bottom - rounded_y + (round_to - 1)) / round_to) * round_to;

          
          if (rounded_x < 0)
            rounded_x = 0;
          if (rounded_y < 0)
            rounded_y = 0;

          
          if (rounded_x + rounded_w > img_w)
            rounded_w = img_w - rounded_x;
          if (rounded_y + rounded_h > img_h)
            rounded_h = img_h - rounded_y;

          int cropped_size = rounded_w * rounded_h * 4;
          if (app.cropped_rgb32)
          {
            free(app.cropped_rgb32);
          }
          app.cropped_rgb32 = calloc(1, cropped_size);
          if (!app.cropped_rgb32)
          {
            free(rgb32);
            free(rgb);
            printf("Failed to allocate memory for cropped_rgb32\n");
            continue;
          }
          int src_stride = img_w * 4;
          int dst_stride = rounded_w * 4;

          for (int y = 0; y < rounded_h; y++)
          {
            memcpy(app.cropped_rgb32 + y * dst_stride,
                   rgb32 + (rounded_y + y) * src_stride + rounded_x * 4,
                   rounded_w * 4);
          }
          
          

          int new_pos_x = pos_x + rounded_x;
          int new_pos_y = pos_y + rounded_y; 

          
          bool change = new_pos_x != last_x || new_pos_y != last_y ||
                        rounded_w != last_w || rounded_h != last_h;

          if (change || move_init < 10)
          {
            if (move_init < 10)
            {
              move_init += 1;
            }

            if (strcmp(desktop_env, "kde") == 0 ||
                strcmp(desktop_env, "plasma") == 0)
            {
              char wmctrl_cmd[512];
              frame_locked = true;
              snprintf(wmctrl_cmd, sizeof(wmctrl_cmd),
                       "wmctrl -r Overlay -e 0,%d,%d,%d,%d",
                       new_pos_x, new_pos_y, rounded_w, rounded_h);
              system(wmctrl_cmd);
              printf("KDE/KWin: Moved/Resized Overlay window to %d,%d with size %dx%d\n",
                     new_pos_x, new_pos_y, rounded_w, rounded_h);
              int wattime = 0;
              while (frame_locked && wattime < 10000)
              {
                wattime += 1000;
                usleep(1000);
              }
              draw_image(app.cropped_rgb32, rounded_w, rounded_h, new_pos_x, new_pos_y, rounded_w, rounded_h, false);
              force_redraw();
              window_x_absolute = new_pos_x;
              window_y_absolute = new_pos_y;
            }
            else
            {
              
              FILE *fp = popen("hyprctl clients | grep -B 10 'title: Overlay' "
                               "| head -n 1 | awk '{print $2}'",
                               "r");
              char address[32] = {0};
              if (fp)
              {
                fgets(address, sizeof(address), fp);
                pclose(fp);
              }
              address[strcspn(address, "\n")] = 0;

              WindowMoveResizeParams *params =
                  malloc(sizeof(WindowMoveResizeParams));
              params->x = new_pos_x;
              params->y = new_pos_y;
              	params->w = rounded_w;
              	params->h = rounded_h;
              window_x_absolute = new_pos_x;
              window_y_absolute = new_pos_y;

              strncpy(params->address, address, sizeof(params->address) - 1);
              params->address[sizeof(params->address) - 1] = '\0';

              pthread_t thread;
              pthread_create(&thread, NULL, async_hyprctl_thread, params);
              pthread_detach(thread);
            }
          }
          else
          {
            draw_image(app.cropped_rgb32, rounded_w, rounded_h, new_pos_x,
                       new_pos_y, rounded_w, rounded_h, false);
          }
          force_redraw();
          free(rgb32);
          last_x = new_pos_x;
          last_y = new_pos_y;
          last_w = rounded_w;
          last_h = rounded_h;
          usleep(10000);
        }

        free(rgb);
      }

      free(full_data);
    }
  }
  close(sock);
  return NULL;
}

int main(int argc, char *argv[])
{
  setup_window();
  char *desktop_env = "kde";

  for (int i = 1; i < argc; ++i)
  {
    if ((strcmp(argv[i], "--desktopenvironnement") == 0 ||
         strcmp(argv[i], "-de") == 0) &&
        i + 1 < argc)
    {
      desktop_env = argv[i + 1];
      i++;
    } else if ((strcmp(argv[i], "--offset") == 0 || strcmp(argv[i], "-o") == 0) && i + 1 < argc) {
        char *value = argv[i + 1];
        char *sep = strchr(value, 'x');
        if (sep) {
        	*sep = '\0';
                screen_x_offset = atoi(value);
                screen_y_offset = atoi(sep + 1);
                *sep = 'x';
                i++;
            }
        }
  }

  load_or_create_config("../config.txt");

  if (desktop_env)
  {
    printf("Desktop environment: %s\n", desktop_env);
  }

  pthread_t recv_thread;
  UdpReceiveThreadArgs *recv_args = malloc(sizeof(UdpReceiveThreadArgs));
  recv_args->arg = NULL;
  recv_args->desktop_env = desktop_env;
  pthread_create(&recv_thread, NULL, udp_receive_thread, recv_args);
  frame_ready = true;
  queue_init(&g_event_queue);

  pthread_t sender_thread;
  pthread_create(&sender_thread, NULL, input_sender_thread, NULL);

  pthread_t dispatch_update_thread;
  pthread_create(&dispatch_update_thread, NULL, dispatch_thread, NULL);

  while (1)
  {
    pause();
  }

  return 0;
}
