#include <stdio.h>

#include "calculator.h"

Instr instrs[] = {
  {Instr_Put, {.Put = {0, 10}}},
  {Instr_Put, {.Put = {1, 20}}},
  {Instr_Put, {.Put = {2, 30}}},
  {Instr_Put, {.Put = {3, 40}}},

  // Compute sum
  {Instr_Op, {.Op = {{Op_Add}, 0, 1, 4}}},
  {Instr_Op, {.Op = {{Op_Add}, 2, 4, 4}}},
  {Instr_Op, {.Op = {{Op_Add}, 3, 4, 4}}},
  {Instr_Get, {.Get = {4, 0xAAAA}}},
  
  // Compute mean
  {Instr_Put, {.Put = {5, 4}}},
  {Instr_Op, {.Op = {{Op_Div}, 4, 5, 4}}},
  {Instr_Get, {.Get = {4, 0xBBBB}}},

  // Compute product
  {Instr_Op, {.Op = {{Op_Mul}, 0, 1, 5}}},
  {Instr_Op, {.Op = {{Op_Mul}, 2, 5, 5}}},
  {Instr_Op, {.Op = {{Op_Mul}, 3, 5, 5}}},
  {Instr_Get, {.Get = {5, 0xCCCC}}},

  Instr_Halt
};

unsigned ic = 0;

unsigned long long getInstr() {
  Instr i = ic < sizeof(instrs) / sizeof(Instr)? instrs[ic] : (Instr){Instr_NoOp};
  ic++;

  unsigned long long out = 0;
  uint8_t out_buf[size_Instr], *out_ptr = &out_buf[0];
  pack_Instr(i, &out_ptr);
  for (int i = 0; i < size_Instr; i++) {
    out <<= 8;
    out |= out_buf[i];
  }
  return out;
}

void putResult(unsigned long long in) {
  uint8_t in_buf[size_Result], *in_ptr = &in_buf[0];
  for (int i = size_Result - 1; i >= 0; i--) {
    in_buf[i] = in & 0xFF;
    in >>= 8;
  }
  Result res = unpack_Result(&in_ptr);

  printf("========= Result %hx: %d =========\n", res.id, res.result);
}
