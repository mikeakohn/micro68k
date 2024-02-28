.68000

.org 0x4000
main:
  add.w #0x1234, d2

  ;move.w #0x1234, d2
  ;move.w #0x1234, d0

  ;move.w d2, d0
  ;add.w d2, d0
  ;add.w d2, (0x0004).l


  move.w d2, (0x0004).l


  ;add.w (0x0004).l, d0


  move.w (0x0004).l, d0

  trap #0

