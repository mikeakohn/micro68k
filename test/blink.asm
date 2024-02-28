.68000

.org 0x4000
main:
  move.l #0x12348000, d2
  swap d2
  move.w d2, d0

  add.w #0x8000, d2
  move.w #0x3, d0
  ;move ccr, d0
  ;move sr, d0
  ;move d0, sr
  move d0, ccr

  ;add.w #0x1234, (0)
  ;move sr, d0
  trap #0

loop:
  ;jmp loop

