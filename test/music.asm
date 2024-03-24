.68000

;.org 0x4000
.org 0xc000

;; Registers.
BUTTON     equ 0x8000
SPI_TX     equ 0x8002
SPI_RX     equ 0x8004
SPI_CTL    equ 0x8006
PORT0      equ 0x8010
SOUND      equ 0x8012
SPI_IO     equ 0x8014

;; Bits in SPI_CTL.
SPI_BUSY   equ 0x01
SPI_START  equ 0x02
SPI_16     equ 0x04

;; Bits in SPI_IO.
LCD_RES    equ 0x01
LCD_DC     equ 0x02
LCD_CS     equ 0x04

;; Bits in PORT0
LED0       equ 0x01

start:

main:

main_while_1:
  jsr delay
  ;; Check button.
  cmpi.w #1, (BUTTON).w
  beq.s run
  ;; LED on.
  move.b #1, (PORT0).w
  jsr delay
  ;; Check button.
  cmpi.w #1, (BUTTON).w
  beq.s run
  ;; LED off.
  move.b #0, (PORT0).w
  jmp main_while_1

run:
  jsr play_song
  bra.s main_while_1

play_song:
  movea.w #song, a0
play_song_loop:
  move.w (a0)+, d0
  move.w (a0)+, d1
  cmp.w #0, d1
  beq.s play_song_exit
  move.b d0, (0x8012).w
play_song_delay:
  move.w #100, d2
play_song_delay_inner:
  sub.w #1, d2
  bne.w play_song_delay_inner
  sub.w #1, d1
  bne.w play_song_delay
  jmp play_song_loop
play_song_exit:
  move.b #0, (0x8012).w
  rts

delay:
  move.w #0xffff, d0
delay_loop:
  subq.l #1, d0
  bne.s delay_loop
  rts

song:
  dw 0,  125, 83, 125, 0,  125, 95, 125, 0,  125, 90, 125, 0,  125,
  dw 87, 125, 0,  125, 95, 125, 90, 125, 0,  250, 87, 250, 0,  250,
  dw 84, 125, 0,  125, 96, 125, 0,  125, 91, 125, 0,  125, 88, 125,
  dw 0,  125, 96, 125, 91, 125, 0,  250, 88, 250, 0,  250, 83, 125,
  dw 0,  125, 95, 125, 0,  125, 90, 125, 0,  125, 87, 125, 0,  125,
  dw 95, 125, 90, 125, 0,  250, 87, 250, 0,  250, 87, 125, 88, 125,
  dw 89, 125, 0,  125, 89, 125, 90, 125, 91, 125, 0,  125, 91, 125,
  dw 92, 125, 93, 125, 0,  125, 95, 187, 0,    0

