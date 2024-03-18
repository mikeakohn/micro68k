.68000

.org 0x4000
main:
  move.w #8, d0

  ;; A word write to a0 zero extends a0.
  ;movea.l #0x1234_5678, a0
  ;movea.w d0, a0
  ;move.l a0, d0
  ;swap d0

  ;; A word write leaves the upper bits as is.
  ;move.l #0x1234_5678, d1
  ;move.w d0, d1
  ;move.l d1, d0
  ;swap d0

  move.w #0xffff, d0
  ;; A word write to a0 sign extends a0.
  movea.l #0x1234_5678, a0
  movea.w d0, a0
  move.l a0, d0
  swap d0

  trap #0

