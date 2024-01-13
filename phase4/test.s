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
  move $a0, $t6
  addi $sp, $sp, -4
  sw $ra, 0($sp)
  jal write
  lw $ra, 0($sp)
  addi $sp, $sp, 4
  j label2
label1:
  move $t7, $a0
  li $s0, 1
  sub $s1, $t7, $s0
  move $s2, $a1
  move $s3, $a3
  move $s4, $a2
  bug here!
  sw $a0, -4($sp)
  move $a0, $s1
  bug here!
  sw $a1, -8($sp)
  move $a1, $s2
  bug here!
  sw $a2, -12($sp)
  move $a2, $s3
  bug here!
  sw $a3, -16($sp)
  move $a3, $s4
  sw $ra, 0($sp)
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
  addi $sp, $sp, -72
  jal hanoi
  addi $sp, $sp, 72
  lw $s4, -68($sp)
  lw $s3, -64($sp)
  lw $s2, -60($sp)
  lw $s1, -56($sp)
  lw $s0, -52($sp)
  lw $t7, -48($sp)
  lw $t6, -44($sp)
  lw $t5, -40($sp)
  lw $t4, -36($sp)
  lw $t3, -32($sp)
  lw $t2, -28($sp)
  lw $t1, -24($sp)
  lw $t0, -20($sp)
  lw $ra, 0($sp)
  move $s5, $v0
  lw $s7 -8($sp)
  move $s6, $s7
  li $t8, 10000
  bug here!
  sw $t0, -20($sp)
  mul $t0, $s6, $t8
  bug here!
  sw $t0, -84($sp)
  bug here!
  sw $t0, -88($sp)
  lw $t0 -16($sp)
  move $t0, $t0
  bug here!
  sw $t0, -16($sp)
  bug here!
  sw $t0, -92($sp)
  lw $t0 -84($sp)
  bug here!
  sw $t0, -84($sp)
  lw $t0 -88($sp)
  add $t0, $t0, $t0
  bug here!
  sw $t0, -88($sp)
  lw $t0 -92($sp)
  move $a0, $t0
  addi $sp, $sp, -4
  sw $ra, 0($sp)
  jal write
  lw $ra, 0($sp)
  addi $sp, $sp, 4
  bug here!
  sw $t0, -92($sp)
  bug here!
  sw $t0, -96($sp)
  lw $t0 -4($sp)
  move $t0, $t0
  bug here!
  sw $t0, -4($sp)
  li $t0, 1
  bug here!
  sw $t0, -100($sp)
  bug here!
  sw $t0, -104($sp)
  lw $t0 -96($sp)
  bug here!
  sw $t0, -96($sp)
  lw $t0 -100($sp)
  sub $t0, $t0, $t0
  bug here!
  sw $t0, -100($sp)
  bug here!
  sw $t0, -108($sp)
  lw $t0 -12($sp)
  move $t0, $t0
  bug here!
  sw $t0, -12($sp)
  move $t0, $s7
  bug here!
  sw $t0, -112($sp)
  bug here!
  sw $t0, -116($sp)
  lw $t0 -16($sp)
  move $t0, $t0
  bug here!
  sw $t0, -16($sp)
  lw $t0 -104($sp)
  move $a0, $t0
  bug here!
  sw $t0, -104($sp)
  lw $t0 -108($sp)
  move $a1, $t0
  bug here!
  sw $t0, -108($sp)
  lw $t0 -112($sp)
  move $a2, $t0
  bug here!
  sw $t0, -112($sp)
  lw $t0 -116($sp)
  move $a3, $t0
  sw $ra, 0($sp)
  sw $t0, -116($sp)
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
  sw $s5, -72($sp)
  sw $s6, -76($sp)
  sw $s7, -8($sp)
  sw $t8, -80($sp)
  addi $sp, $sp, -120
  jal hanoi
  addi $sp, $sp, 120
  lw $t8, -80($sp)
  lw $s7, -8($sp)
  lw $s6, -76($sp)
  lw $s5, -72($sp)
  lw $s4, -68($sp)
  lw $s3, -64($sp)
  lw $s2, -60($sp)
  lw $s1, -56($sp)
  lw $s0, -52($sp)
  lw $t7, -48($sp)
  lw $t6, -44($sp)
  lw $t5, -40($sp)
  lw $t4, -36($sp)
  lw $t3, -32($sp)
  lw $t2, -28($sp)
  lw $t1, -24($sp)
  lw $t0, -116($sp)
  lw $ra, 0($sp)
  bug here!
  sw $t0, -116($sp)
  move $t0, $v0
label2:
  bug here!
  sw $t0, -120($sp)
  li $t0, 0
  move $v0, $t0
  jr $ra
main:
  li $t0, 3
  move $t1, $t0
  move $t2, $t1
  li $t3, 1
  li $t4, 2
  li $t5, 3
  move $a0, $t2
  move $a1, $t3
  move $a2, $t4
  move $a3, $t5
  sw $ra, 0($sp)
  sw $t0, -4($sp)
  sw $t1, -8($sp)
  sw $t2, -12($sp)
  sw $t3, -16($sp)
  sw $t4, -20($sp)
  sw $t5, -24($sp)
  addi $sp, $sp, -28
  jal hanoi
  addi $sp, $sp, 28
  lw $t5, -24($sp)
  lw $t4, -20($sp)
  lw $t3, -16($sp)
  lw $t2, -12($sp)
  lw $t1, -8($sp)
  lw $t0, -4($sp)
  lw $ra, 0($sp)
  move $t6, $v0
  li $t7, 0
  move $v0, $t7
  jr $ra
