micro68k
========

This is a "micro" implementation of the Motorola 68000. The
board being used here is an iceFUN with a Lattice iCE40 HX8K FPGA.

Website:
https://www.mikekohn.net/micro/micro_x86_68000_fpga.php

instructions
------------
Implemented:

    add
    adda
    addi
    addq
    and
    andi
    asl
    asr
    bcc
    bchg
    bclr
    bset
    bsr
    bra
    btst
    clr
    cmp
    cmpa
    cmpi
    eor
    eori
    jmp
    jsr
    lea
    lsl
    lsr
    move
    mov from SR
    move to SR
    move to CCR
    moveq
    neg
    ori
    rol
    ror
    rts
    sub
    suba
    subi
    subq
    swap
    trap #num

Not implemented:

    asl <ea>
    asr <ea>
    exg
    lsl <ea>
    lsr <ea>
    pea
    rol <ea>
    ror <ea>
    Scc

The trap instruction is used to put the CPU in a halted state. Using
trap #1, the CPU will go into the ERROR state while any other value
will put the CPU into the HALTED state.

This implementation of the Motorola 68000 has 4 banks of memory.

* Bank 0: RAM (4096 bytes)
* Bank 1: ROM (4096 bytes loaded from rom.txt)
* Bank 2: Peripherals
* Bank 3: RAM (4096 bytes)

On start-up by default, the chip will load a program from a AT93C86A
2kB EEPROM with a 3-Wire (SPI-like) interface but wll run the code
from the ROM. To start the program loaded to RAM, the program select
button needs to be held down while the chip is resetting.

* 0x8000: input from push button
* 0x8002: SPI TX
* 0x8004: SPI RX
* 0x8006: SPI CTRL
* 0x8010: ioport0 output (in my test case only 1 pin is connected)
* 0x8012: MIDI note value (60-96) to play a tone on the speaker or 0 to stop
* 0x8014: ioport1

