#include <stdio.h>

#include "test.h"

unsigned int test_fn(unsigned long long in) {
  printf("Called test_fn %llx\n", in);
  uint8_t in_buf[6], *in_ptr = &in_buf[0];
  for (int i = 5; i >= 0; i--) {
    in_buf[i] = in & 0xFF;
    in >>= 8;
  }
  ThingMsg msg = unpack_ThingMsg(&in_ptr);
  printf("Unpacked msg: %hhu %hhu %hd %hhd %hhd\n", msg.thing.x, msg.thing.y, msg.thing.z, msg.swapXY, msg.deltaZ);
  
  Thing res;
  if (msg.swapXY) {
    res.x = msg.thing.y;
    res.y = msg.thing.x;
  } else {
    res.x = msg.thing.x;
    res.y = msg.thing.y;
  }
  res.z = msg.thing.z + msg.deltaZ;
  printf("res: %hhu %hhu %hd\n", res.x, res.y, res.z);

  unsigned int out = 0;
  uint8_t out_buf[4], *out_ptr = &out_buf[0];
  pack_Thing(res, &out_ptr);
  for (int i = 0; i < 4; i++) {
    out |= out_buf[i];
    out <<= 8;
  }
  printf("Packed res: %x\n", out);
  return out;
}
