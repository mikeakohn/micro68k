.68000

.org 0x4000
main:
  add.w #0x8000, d2

  jsr turn_on_led

  move.w #0x80, d0
  trap #0

.org 0x4200
turn_on_led:
  move.w #1, (0x8010).w
  move.w #0x08, d0
  rts
  trap #0

