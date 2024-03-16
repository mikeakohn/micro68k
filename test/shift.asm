.68000

.org 0x4000
main:
  move.l #0x12340000, d0
  asr.l #8, d0
  asr.l #8, d0
  trap #0

