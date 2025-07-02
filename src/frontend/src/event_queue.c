#include "event_queue.h"
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <netinet/in.h>
#include "app_state.h"

#define SERVER_IP "127.0.0.1"
#define INPUT_SERVER_PORT 4090

EventQueue g_event_queue = {
    .head = 0,
    .tail = 0,
    .mutex = PTHREAD_MUTEX_INITIALIZER,
    .cond = PTHREAD_COND_INITIALIZER};

void queue_init(EventQueue *q)
{
    q->head = q->tail = NULL;
    pthread_mutex_init(&q->mutex, NULL);
    pthread_cond_init(&q->cond, NULL);
}

void enqueue(EventQueue *q, InputEvent *ev)
{
    ev->next = NULL;
    pthread_mutex_lock(&q->mutex);
    if (q->tail)
    {
        q->tail->next = ev;
        q->tail = ev;
    }
    else
    {
        q->head = q->tail = ev;
    }
    pthread_cond_signal(&q->cond);
    pthread_mutex_unlock(&q->mutex);
}

InputEvent *dequeue(EventQueue *q)
{
    pthread_mutex_lock(&q->mutex);
    while (!q->head)
    {
        pthread_cond_wait(&q->cond, &q->mutex);
    }
    InputEvent *ev = q->head;
    q->head = ev->next;
    if (!q->head)
        q->tail = NULL;
    pthread_mutex_unlock(&q->mutex);
    return ev;
}

void *input_sender_thread(void *arg)
{
    int sock = socket(AF_INET, SOCK_DGRAM, 0);
    if (sock < 0)
    {
        perror("socket");
        return NULL;
    }
    struct sockaddr_in server_addr = {0};
    server_addr.sin_family = AF_INET;
    server_addr.sin_port = htons(INPUT_SERVER_PORT);
    inet_pton(AF_INET, SERVER_IP, &server_addr.sin_addr);

    while (1)
    {
        InputEvent *ev = dequeue(&g_event_queue);
        uint8_t buffer[7];
        buffer[0] = ev->type;
        int16_t nx = htons(ev->x);
        int16_t ny = htons(ev->y);
        memcpy(buffer + 1, &nx, 2);
        memcpy(buffer + 3, &ny, 2);
        buffer[5] = ev->button;
        buffer[6] = 0;
        sendto(sock, buffer, 7, 0, (struct sockaddr *)&server_addr, sizeof(server_addr));
        printf("Sent event: type=%d, x=%d, y=%d, button=%d\n", ev->type, ev->x, ev->y, ev->button);
        free(ev);
    }
    close(sock);
    return NULL;
}