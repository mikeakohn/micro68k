.68000

.org 0x4000
main:
  moveq #2, d0
  moveq #4, d2
  bset #9, d0
  bset d2, d0
  ;move.w d3, d0
  trap #0

