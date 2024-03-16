.68000

.org 0x4000
main:
  jsr run
  trap #0

run:
  move.w #1024, d0
run_loop:
  jsr test_memory
  sub.w #1, d0
  bne.s run_loop
  rts

test_memory:
  movea.l #0xc000, a0
  move.w #0, d1
test_memory_loop_write:
  move.w d1, (0,a0,d1.w)
  add.w #2, d1
  cmp.w #200, d1
  bne.s test_memory_loop_write

  move.w #0, d1
  movea.w #0xc000, a1
test_memory_loop_read:
  move.w (0,a0,d1.w), d2
  move.w (a1)+, d3
  cmp.w d1, d2
  bne.s error_1
  cmp.w d1, d3
  bne.s error_2
  add.w #2, d1
  cmp.w #200, d1
  bne.s test_memory_loop_read
  rts

error_1:
  move.w d2, d0
  trap #1

error_2:
  move.w d1, d0
  trap #1

test:
  ;move.w #6, d2
  ;move.w #0x1234, d1
  ;move.w #0xaa55, d3
  ;move.w d1, (2,a0,d2.w)
  ;move.w d3, (4,a0,d2.w)
  ;;move.w (0xc008).w, d0
  ;move.w (2,a0,d2.w), d0
  ;trap #0

