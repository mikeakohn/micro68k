.68000

.org 0x4000
main:
  add.w #0x8000, d2
  bpl.w blah

  move.w #0x80, d0
  trap #0

.org 0x4200
blah:
  move.w #0x08, d0
  trap #0

