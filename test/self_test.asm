.68000

.org 0x4000
main:
  move.w #0, d0
  addq.w #8, d0

  ;; Make sure Z=0, S=0, C=0.
.scope
  bne.s test_0
  trap #1
test_0:
  bpl.s test_1
  trap #1
test_1:
  bcc.s test_2
  trap #1
test_2:
.ends

  subq.w #8, d0

  ;; Make sure Z=1, S=0, C=0.
.scope
  beq.s test_0
  trap #1
test_0:
  bpl.s test_1
  trap #1
test_1:
  bcc.s test_2
  trap #1
test_2:
.ends

  subq.w #8, d0

  ;; Make sure Z=0, S=1, C=1.
.scope
  bne.s test_0
  trap #1
test_0:
  bmi.s test_1
  trap #1
test_1:
  bcs.s test_2
  trap #1
test_2:
.ends

  trap #0

