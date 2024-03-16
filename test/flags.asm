.68000

.org 0x4000
main:
  ;move.w #0xff00, d0
  ;add.w #1, d0

  move.w #1, d2
  subq.w #1, d2
  ;move.w d2, d0
  move ccr, d0

  move.w #5, d0
  add.w #2, d0
  ;move.w #7, d1
  cmp.w #7, d0
  bne.s not_same

  ;move.w #0xf000, d2
  ;move d2, sr

  ;move sr, d0
  trap #0

not_same:
  trap #1

