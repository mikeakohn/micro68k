micro68k
========

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
    bchg
    bclr
    bset
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

