.68000

.org 0x4000
main:
  add.w #0x4000, d2
  bpl.w blah

  move.w #0x80, d0
  trap #0

  move.w #17, d0
  trap #0
roar:
  move.w #7, d0
  nop
  nop
  nop
  nop
  trap #1

.org 0x4200
blah:
  move.w #0x08, d0
  bra.w roar
  trap #0

