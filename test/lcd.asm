.68000

.org 0x4000

;; Variables.
curr_x equ 0
curr_y equ 2
curr_r equ 4
curr_i equ 6
zr     equ 8
zi     equ 10
count  equ 12
zr2    equ 14
zi2    equ 16
tr     equ 18
ti     equ 20

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

COMMAND_DISPLAY_OFF     equ 0xae
COMMAND_SET_REMAP       equ 0xa0
COMMAND_START_LINE      equ 0xa1
COMMAND_DISPLAY_OFFSET  equ 0xa2
COMMAND_NORMAL_DISPLAY  equ 0xa4
COMMAND_SET_MULTIPLEX   equ 0xa8
COMMAND_SET_MASTER      equ 0xad
COMMAND_POWER_MODE      equ 0xb0
COMMAND_PRECHARGE       equ 0xb1
COMMAND_CLOCKDIV        equ 0xb3
COMMAND_PRECHARGE_A     equ 0x8a
COMMAND_PRECHARGE_B     equ 0x8b
COMMAND_PRECHARGE_C     equ 0x8c
COMMAND_PRECHARGE_LEVEL equ 0xbb
COMMAND_VCOMH           equ 0xbe
COMMAND_MASTER_CURRENT  equ 0x87
COMMAND_CONTRASTA       equ 0x81
COMMAND_CONTRASTB       equ 0x82
COMMAND_CONTRASTC       equ 0x83
COMMAND_DISPLAY_ON      equ 0xaf

.macro send_command(value)
  move.w #value, d0
  jsr lcd_send_cmd
.endm

start:

main:
  jsr lcd_init
  jsr lcd_clear

  ;jmp test_mul

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
  jsr lcd_clear_2
  jsr mandelbrot
  bra.s main_while_1

lcd_init:
  move.w #LCD_CS, (SPI_IO).w
  jsr delay
  move.w #LCD_CS | LCD_RES, (SPI_IO).w

  send_command(COMMAND_DISPLAY_OFF)
  send_command(COMMAND_SET_REMAP)
  send_command(0x72)
  send_command(COMMAND_START_LINE)
  send_command(0x00)
  send_command(COMMAND_DISPLAY_OFFSET)
  send_command(0x00)
  send_command(COMMAND_NORMAL_DISPLAY)
  send_command(COMMAND_SET_MULTIPLEX)
  send_command(0x3f)
  send_command(COMMAND_SET_MASTER)
  send_command(0x8e)
  send_command(COMMAND_POWER_MODE)
  send_command(COMMAND_PRECHARGE)
  send_command(0x31)
  send_command(COMMAND_CLOCKDIV)
  send_command(0xf0)
  send_command(COMMAND_PRECHARGE_A)
  send_command(0x64)
  send_command(COMMAND_PRECHARGE_B)
  send_command(0x78)
  send_command(COMMAND_PRECHARGE_C)
  send_command(0x64)
  send_command(COMMAND_PRECHARGE_LEVEL)
  send_command(0x3a)
  send_command(COMMAND_VCOMH)
  send_command(0x3e)
  send_command(COMMAND_MASTER_CURRENT)
  send_command(0x06)
  send_command(COMMAND_CONTRASTA)
  send_command(0x91)
  send_command(COMMAND_CONTRASTB)
  send_command(0x50)
  send_command(COMMAND_CONTRASTC)
  send_command(0x7d)
  send_command(COMMAND_DISPLAY_ON)
  rts

lcd_clear:
  move.w #96 * 64, d7
lcd_clear_loop:
  move.w #0x0f0f, d0
  jsr lcd_send_data
  subq.w #1, d7
  bne.s lcd_clear_loop
  rts

lcd_clear_2:
  move.w #96 * 64, d7
lcd_clear_loop_2:
  move.w #0xf00f, d0
  jsr lcd_send_data
  subq.w #1, d7
  bne.s lcd_clear_loop_2
  rts

;; multiply(d6, d7) -> d0
multiply:
  moveq.l #0, d0
multiply_loop:
  lsr.l #1, d7
  bcc.s multiply_skip_add
  add.l d6, d0
multiply_skip_add:
  lsl.l #1, d6
  cmp.l #0, d7
  bne.s multiply_loop
  asr.l #8, d0
  asr.l #2, d0
  and.l #0xffff, d0
  rts

;; multiply_signed(d6, d7) -> d0
multiply_signed:
  move.w #0, d5
  btst #15, d7
  beq.s multiply_signed_d7_pos
  addq.w #1, d5
  neg.w d7
multiply_signed_d7_pos:
  btst #15, d6
  beq.s multiply_signed_d6_pos
  addq.w #1, d5
  neg.w d6
multiply_signed_d6_pos:
  and.l #0xffff, d7
  and.l #0xffff, d6
  moveq.l #0, d0
multiply_signed_loop:
  lsr.l #1, d7
  bcc.s multiply_signed_skip_add
  add.l d6, d0
multiply_signed_skip_add:
  lsl.l #1, d6
  cmp.l #0, d7
  bne.s multiply_signed_loop
  asr.l #8, d0
  asr.l #2, d0
  and.l #0xffff, d0
  btst #0, d5
  beq.s multiply_signed_exit
  neg.w d0
multiply_signed_exit:
  rts

mandelbrot:
  ;; Store local variables in 0xc000 pointed to by a0.
  movea.l #0xc000, a0
  movea.l #colors, a1

  ;; 0:  uint16_t x;
  ;; 2:  uint16_t y;
  ;; 4:  uint16_t r;
  ;; 6:  uint16_t i;
  ;; 8:  uint16_t zr;
  ;; 10: uint16_t zi;
  ;; final int DEC_PLACE = 10;
  ;; final int r0 = (-2 << DEC_PLACE);
  ;; final int i0 = (-1 << DEC_PLACE);
  ;; final int r1 = (1 << DEC_PLACE);
  ;; final int i1 = (1 << DEC_PLACE);
  ;; final int dx = (r1 - r0) / 96; (0x0020)
  ;; final int dy = (i1 - i0) / 64; (0x0020)

  ;; for (y = 0; y < 64; y++)
  move.w #64, (curr_y,a0)

  ;; int i = -1 << 10;
  move.w #0xfc00, (curr_i,a0)
mandelbrot_for_y:

  ;; for (x = 0; x < 96; x++)
  move.w #96, (a0)

  ;; int r = -2 << 10;
  move.w #0xf800, (curr_r,a0)
mandelbrot_for_x:
  ;; zr = r;
  ;; zi = i;
  move.w (curr_r,a0), d0
  move.w (curr_i,a0), d1
  move.w d0, (zr,a0)
  move.w d1, (zi,a0)

  ;; for (int count = 0; count < 15; count++)
  move.w #15, d2
mandelbrot_for_count:
  ;; zr2 = (zr * zr) >> DEC_PLACE;
  move.w (zr,a0), d7
  move.w d7, d6
  jsr multiply_signed
  move.w d0, (zr2,a0)

  ;; zi2 = (zi * zi) >> DEC_PLACE;
  move.w (zi,a0), d7
  move.w d7, d6
  jsr multiply_signed
  move.w d0, (zi2,a0)

  ;; if (zr2 + zi2 > (4 << DEC_PLACE)) { break; }
  ;; cmp does: 4 - (zr2 + zi2).. if it's negative it's bigger than 4.
  move.w (zr2,a0), d0
  add.w (zi2,a0), d0
  cmp.w #4 << 10, d0
  bgt.s mandelbrot_stop
  ;bhi.s mandelbrot_stop

  ;; tr = zr2 - zi2;
  move.w (zr2,a0), d0
  sub.w (zi2,a0), d0
  move.w d0, (tr,a0)

  ;; ti = ((zr * zi * 2)
  move.w (zr,a0), d7
  move.w (zi,a0), d6
  jsr multiply_signed
  lsl.w #1, d0
  move.w d0, (ti,a0)

  ;; zr = tr + curr_r;
  move.w (tr,a0), d0
  add.w (curr_r,a0), d0
  move.w d0, (zr,a0)

  ;; zi = ti + curr_i;
  move.w (ti,a0), d0
  add.w (curr_i,a0), d0
  move.w d0, (zi,a0)

  subq.w #1, d2
  bne.s mandelbrot_for_count
mandelbrot_stop:

  move.w (0,a1,d2*2), d0
  ;move.w #0x000f, d0

  jsr lcd_send_data

  add.w #0x0020, (curr_r,a0)
  subq.w #1, (a0)
  bne.w mandelbrot_for_x

  add.w #0x0020, (curr_i,a0)
  subq.w #1, (curr_y,a0)
  bne.w mandelbrot_for_y
  rts

  ;; Some test code.
test_mul:
  ;move.l #2, d6
  ;move.l #0xfff0, d7
  ;jsr multiply_signed
  ;trap #0

;; lcd_send_cmd(d0)
lcd_send_cmd:
  move.w #LCD_RES, (SPI_IO).w
  move.b d0, (SPI_TX).w
  move.b #SPI_START, (SPI_CTL).w
lcd_send_cmd_wait:
  btst #0, (SPI_CTL).w
  bne.s lcd_send_cmd_wait
  move.w #LCD_CS | LCD_RES, (SPI_IO).w
  rts

;; lcd_send_data(d0)
lcd_send_data:
  move.w #LCD_DC | LCD_RES, (SPI_IO).w
  move.w d0, (SPI_TX).w
  move.b #SPI_16 | SPI_START, (SPI_CTL).w
lcd_send_data_wait:
  btst #0, (SPI_CTL).w
  bne.s lcd_send_data_wait
  move.w #LCD_CS | LCD_RES, (SPI_IO).w
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

colors:
  dc16 0x0000
  dc16 0x000c
  dc16 0x0013
  dc16 0x0015
  dc16 0x0195
  dc16 0x0335
  dc16 0x04d5
  dc16 0x34c0
  dc16 0x64c0
  dc16 0x9cc0
  dc16 0x6320
  dc16 0xa980
  dc16 0xaaa0
  dc16 0xcaa0
  dc16 0xe980
  dc16 0xf800

