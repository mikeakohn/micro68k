.68000

.org 0x4000
main:
  jsr delay
  jsr led_on
  jsr delay
  jsr led_off
  jmp main

  trap #0

led_on:
  ;; FIXME: this fails.
  move.w #1, (0x8010).w
  ;move.w #1, d0
  ;move.w d0, (0x8010).w
  rts

led_off:
  move.w #0, (0x8010).w
  ;move.w #0, d0
  ;move.w d0, (0x8010).w
  rts

delay:
  move.w #0xffff, d0
  ;move.w #0, d0
delay_loop:
  subq.l #1, d0
  ;addq.l #1, d0
  ;sub.l #1, d0
  bne.s delay_loop
  rts

