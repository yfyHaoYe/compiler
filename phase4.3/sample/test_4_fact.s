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
fact:
  li $v1, 1
  beq $a0, $v1, label1
  j label2
label1:
  move $v0, $a0
  jr $ra
label2:
  addi $t0, $a0, -1
  sw $a0, -4($sp)
  sw $t0, -8($sp)
  move $a0, $t0
  sw $ra, 0($sp)
  addi $sp, $sp, -12
  jal fact
  addi $sp, $sp, 12
  lw $ra, 0($sp)
  lw $t0 -8($sp)
  lw $a0 -4($sp)
  move $t1, $v0
  mul $t2, $a0, $t1
  move $v0, $t2
  jr $ra
main:
  addi $sp, $sp, -4
  sw $ra, 0($sp)
  jal read
  lw $ra, 0($sp)
  addi $sp, $sp, 4
  move $t0, $v0
  move $t1, $t0
  li $v1, 1
  bgt $t1, $v1, label3
  j label4
label3:
  sw $t0, -4($sp)
  sw $t1, -8($sp)
  move $a0, $t1
  sw $ra, 0($sp)
  addi $sp, $sp, -12
  jal fact
  addi $sp, $sp, 12
  lw $ra, 0($sp)
  lw $t1 -8($sp)
  lw $t0 -4($sp)
  move $t2, $v0
  move $t3, $t2
  j label5
label4:
  li $t3, 1
label5:
  move $a0, $t3
  sw $ra, 0($sp)
  addi $sp, $sp, -4
  jal write
  addi $sp, $sp, 4
  lw $ra, 0($sp)
  li $v0, 0
  jr $ra
