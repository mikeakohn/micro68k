.68000

.org 0x4000
main:
  moveq #4, d0
  bset #2, d0

  move sr, d0

  ;bset d2, d0
  ;move.w d3, d0

  trap #0

