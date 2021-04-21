#include <stdio.h>
#include <string.h>
#include <stdbool.h>

#include "counter.h"

CounterMsgs_state state;
bool initialized = false;

uint8_t out_buf[size_ctob_CounterMsgs + 1] = {0};
bool avail = false;

unsigned i, j = 0;
unsigned responses = 0;
// return (i < 100 && j < 3) || responses > 300;

unsigned char messageAvailable() {
  if (!avail) {
    size_t size = encode_CounterMsgs(&state, out_buf + 1);
    out_buf[0] = size;
    avail = size > 0;
  }
  return avail;
}

unsigned long long getMessage() {
  if (!initialized) {
    init_CounterMsgs(&state);
    initialized = true;
  }

  if (!avail) {
    size_t size = encode_CounterMsgs(&state, out_buf + 1);
    out_buf[0] = size;
    avail = size > 0;
  }

  unsigned long long out = 0;
  for (int i = 0; i < size_ctob_CounterMsgs + 1; i++) {
    out <<= 8;
    out |= out_buf[i];
  }
  memset(out_buf, 0, sizeof(out_buf));
  return out;
}

unsigned char putResult(unsigned long long in) {
  if (!initialized) {
    init_CounterMsgs(&state);
    initialized = true;
  }

  uint8_t in_buf[size_btoc_CounterMsgs];
  for (int i = size_btoc_CounterMsgs - 1; i >= 0; i--) {
    in_buf[i] = in & 0xFF;
    in >>= 8;
  }
  return encode_CounterMsgs(&state, in_buf);
}
