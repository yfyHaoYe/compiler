# SPL compiler generated assembly
.data
_prmpt: .asciiz "Enter an integer: "
_eol: .asciiz "\n"
.globl main
.text
read:
  li $v0, 4
  la $a0, _prmpt
  syscall
  li $v0, 5
  syscall
  jr $ra
write:
  li $v0, 1
  syscall
  li $v0, 4
  la $a0, _eol
  syscall
  move $v0, $0
  jr $ra
hanoi:
  move $t0, $a0
  li $t1, 1
  beq $t0, $t1, label0
  j label1
label0:
  move $t2, $a1
  li $t3, 10000
  mul $t4, $t2, $t3
  move $t5, $a3
  add $t6, $t4, $t5
  sw $a0, -4($sp)
  move $a0, $t6
  sw $ra, 0($sp)
  addi $sp, $sp, -4
  jal write
  addi $sp, $sp, 4
  lw $ra, 0($sp)
  lw $a0, -4($sp)
  j label2
label1:
  move $t7, $a0
  li $s0, 1
  sub $s1, $t7, $s0
  move $s2, $a1
  move $s3, $a3
  move $s4, $a2
  sw $a0, -4($sp)
  sw $a1, -8($sp)
  sw $a2, -12($sp)
  sw $a3, -16($sp)
  sw $t0, -20($sp)
  sw $t1, -24($sp)
  sw $t2, -28($sp)
  sw $t3, -32($sp)
  sw $t4, -36($sp)
  sw $t5, -40($sp)
  sw $t6, -44($sp)
  sw $t7, -48($sp)
  sw $s0, -52($sp)
  sw $s1, -56($sp)
  sw $s2, -60($sp)
  sw $s3, -64($sp)
  sw $s4, -68($sp)
  move $a3, $s4
  move $a2, $s3
  move $a1, $s2
  move $a0, $s1
  sw $ra, 0($sp)
  addi $sp, $sp, -72
  jal hanoi
  addi $sp, $sp, 72
  lw $ra, 0($sp)
  lw $s4 -68($sp)
  lw $s3 -64($sp)
  lw $s2 -60($sp)
  lw $s1 -56($sp)
  lw $s0 -52($sp)
  lw $t7 -48($sp)
  lw $t6 -44($sp)
  lw $t5 -40($sp)
  lw $t4 -36($sp)
  lw $t3 -32($sp)
  lw $t2 -28($sp)
  lw $t1 -24($sp)
  lw $t0 -20($sp)
  lw $a3 -16($sp)
  lw $a2 -12($sp)
  lw $a1 -8($sp)
  lw $a0 -4($sp)
  move $s5, $v0
  move $s6, $a1
  li $t0, 10000
  mul $t1, $s6, $t0
  move $t2, $a3
  add $t3, $t1, $t2
  move $a0, $t3
  sw $ra, 0($sp)
  addi $sp, $sp, -4
  jal write
  addi $sp, $sp, 4
  lw $ra, 0($sp)
  lw $a0, -4($sp)
  move $t4, $a0
  li $t5, 1
  sub $t6, $t4, $t5
  move $t7, $a2
  move $s0, $a1
  move $s1, $a3
  sw $t0, -80($sp)
  sw $t1, -84($sp)
  sw $t2, -88($sp)
  sw $t3, -92($sp)
  sw $t4, -96($sp)
  sw $t5, -100($sp)
  sw $t6, -104($sp)
  sw $t7, -108($sp)
  sw $s0, -112($sp)
  sw $s1, -116($sp)
  sw $s5, -72($sp)
  sw $s6, -76($sp)
  move $a3, $s1
  move $a2, $s0
  move $a1, $t7
  move $a0, $t6
  sw $ra, 0($sp)
  addi $sp, $sp, -120
  jal hanoi
  addi $sp, $sp, 120
  lw $ra, 0($sp)
  lw $s6 -76($sp)
  lw $s5 -72($sp)
  lw $s1 -116($sp)
  lw $s0 -112($sp)
  lw $t7 -108($sp)
  lw $t6 -104($sp)
  lw $t5 -100($sp)
  lw $t4 -96($sp)
  lw $t3 -92($sp)
  lw $t2 -88($sp)
  lw $t1 -84($sp)
  lw $t0 -80($sp)
  move $t0, $v0
label2:
  li $t1, 0
  move $v0, $t1
  jr $ra
main:
  li $t0, 3
  move $t1, $t0
  move $t2, $t1
  li $t3, 1
  li $t4, 2
  li $t5, 3
  sw $t0, -4($sp)
  sw $t1, -8($sp)
  sw $t2, -12($sp)
  sw $t3, -16($sp)
  sw $t4, -20($sp)
  sw $t5, -24($sp)
  move $a3, $t5
  move $a2, $t4
  move $a1, $t3
  move $a0, $t2
  sw $ra, 0($sp)
  addi $sp, $sp, -28
  jal hanoi
  addi $sp, $sp, 28
  lw $ra, 0($sp)
  lw $t5 -24($sp)
  lw $t4 -20($sp)
  lw $t3 -16($sp)
  lw $t2 -12($sp)
  lw $t1 -8($sp)
  lw $t0 -4($sp)
  move $t6, $v0
  li $t7, 0
  move $v0, $t7
  jr $ra
