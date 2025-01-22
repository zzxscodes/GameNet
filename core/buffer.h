#ifndef buffer_h
#define buffer_h
#include <stdint.h>

// Structure representing a chain of buffers
typedef struct buf_chain_s {
    struct buf_chain_s *next;  // Pointer to the next buffer chain
    uint32_t buffer_len;       // Length of the buffer
    uint32_t misalign;         // Misalignment offset
    uint32_t off;              // Offset for data in the buffer
    uint8_t *buffer;           // Pointer to the actual buffer data
} buf_chain_t;

// Structure representing a buffer
typedef struct buffer_s {
    buf_chain_t *first;            // Pointer to the first buffer chain
    buf_chain_t *last;             // Pointer to the last buffer chain
    buf_chain_t **last_with_datap; // Pointer to the last buffer chain with data
    uint32_t total_len;            // Total length of data in the buffer
    uint32_t last_read_pos;        // Position of the last read (for separated reads)
} buffer_t;

// Returns a pointer to a chunk of available data in the buffer
uint8_t* buffer_available_chunk(buffer_t *buf, uint32_t datlen);

// Adds data to the buffer
int buffer_add(buffer_t *buf, const void *data, uint32_t datlen);

// Removes data from the buffer
int buffer_remove(buffer_t *buf, void *data, uint32_t datlen);

// Drains (removes) a specified length of data from the buffer
int buffer_drain(buffer_t *buf, uint32_t len);

// Frees all buffer chains
void buf_chain_free_all(buf_chain_t *chain);

// Searches for a separator in the buffer
int buffer_search(buffer_t *buf, const char* sep, const int seplen);

// Writes data to the buffer, up to a maximum length
uint8_t * buffer_write_atmost(buffer_t *p);

#endif
