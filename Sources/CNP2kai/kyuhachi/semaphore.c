// Counting semaphore for NP2kai's threads (the ssem_* API declared in
// sdl/libretro/rsemaphore.h), written with POSIX threads. Replaces
// sdl/libretro/rsemaphore.c, which is GPL-licensed.

#include <pthread.h>
#include <stdlib.h>

#include "rsemaphore.h"

struct ssem
{
	pthread_mutex_t mutex;
	pthread_cond_t available;
	int count;
};

ssem_t *ssem_new(int value)
{
	ssem_t *semaphore = (ssem_t *)calloc(1, sizeof(*semaphore));

	if (semaphore == NULL)
	{
		return NULL;
	}
	if (pthread_mutex_init(&semaphore->mutex, NULL) != 0)
	{
		free(semaphore);
		return NULL;
	}
	if (pthread_cond_init(&semaphore->available, NULL) != 0)
	{
		pthread_mutex_destroy(&semaphore->mutex);
		free(semaphore);
		return NULL;
	}
	semaphore->count = value;
	return semaphore;
}

void ssem_free(ssem_t *semaphore)
{
	if (semaphore == NULL)
	{
		return;
	}
	pthread_cond_destroy(&semaphore->available);
	pthread_mutex_destroy(&semaphore->mutex);
	free(semaphore);
}

int ssem_get(ssem_t *semaphore)
{
	int count;

	if (semaphore == NULL)
	{
		return 0;
	}
	pthread_mutex_lock(&semaphore->mutex);
	count = semaphore->count;
	pthread_mutex_unlock(&semaphore->mutex);
	return count;
}

void ssem_wait(ssem_t *semaphore)
{
	if (semaphore == NULL)
	{
		return;
	}
	pthread_mutex_lock(&semaphore->mutex);
	while (semaphore->count <= 0)
	{
		pthread_cond_wait(&semaphore->available, &semaphore->mutex);
	}
	semaphore->count--;
	pthread_mutex_unlock(&semaphore->mutex);
}

void ssem_signal(ssem_t *semaphore)
{
	if (semaphore == NULL)
	{
		return;
	}
	pthread_mutex_lock(&semaphore->mutex);
	semaphore->count++;
	pthread_cond_signal(&semaphore->available);
	pthread_mutex_unlock(&semaphore->mutex);
}
