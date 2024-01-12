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
  beq $a0, 1, label1
  j label2
label1:
  move $v0, $a0
  jr $ra
label2:
  addi $t0, $a0, -1
  sw $a0, -4($sp)
  move $a0, $t0
  addi $sp, $sp, -4
  sw $ra, 0($sp)
  jal fact
  lw $ra, 0($sp)
  addi $sp, $sp, 4
  move $t1, $v0
  lw $t3 -4($sp)
  mul $t2, $t3, $t1
  move $v0, $t2
  jr $ra
main:
  addi $sp, $sp, -4
  sw $ra, 0($sp)
  jal read
  lw $ra, 0($sp)
  addi $sp, $sp, 4
  move $t4, $v0
  move $t5, $t4
  bgt $t5, 1, label3
  j label4
label3:
  move $a0, $t5
  addi $sp, $sp, -4
  sw $ra, 0($sp)
  jal fact
  lw $ra, 0($sp)
  addi $sp, $sp, 4
  move $t6, $v0
  move $t7, $t6
  j label5
label4:
  li $t7, 1
label5:
  move $a0, $t7
  addi $sp, $sp, -4
  sw $ra, 0($sp)
  jal write
  lw $ra, 0($sp)
  addi $sp, $sp, 4
  li $v0, 0
  jr $ra
