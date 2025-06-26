#ifndef EVENT_QUEUE_H
#define EVENT_QUEUE_H

#include <pthread.h>
#include <stdint.h>

typedef struct InputEvent {
    uint8_t type;
    int16_t x;
    int16_t y;
    uint8_t button;
    struct InputEvent* next;
} InputEvent;

typedef struct {
    InputEvent* head;
    InputEvent* tail;
    pthread_mutex_t mutex;
    pthread_cond_t cond;
} EventQueue;

extern EventQueue g_event_queue;

void queue_init(EventQueue* q);
void enqueue(EventQueue* q, InputEvent* ev);
InputEvent* dequeue(EventQueue* q);
void* input_sender_thread(void* arg);

#endif