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
main:
  addi $sp, $sp, -4
  sw $ra, 0($sp)
  jal read
  lw $ra, 0($sp)
  addi $sp, $sp, 4
  move $t0, $v0
  move $t1, $t0
  move $t2, $t1
  li $t3, 0
  bgt $t2, $t3, label0
  j label1
label0:
  li $t4, 1
  move $a0, $t4
  sw $ra, 0($sp)
  addi $sp, $sp, -4
  jal write
  addi $sp, $sp, 4
  lw $ra, 0($sp)
  j label2
label1:
  move $t4, $t1
  li $t5, 0
  blt $t4, $t5, label3
  j label4
label3:
  li $t6, 1
  neg $t6, $t6
  addi $t7, $t6, 0
  move $a0, $t7
  sw $ra, 0($sp)
  addi $sp, $sp, -4
  jal write
  addi $sp, $sp, 4
  lw $ra, 0($sp)
  j label5
label4:
  li $t6, 0
  move $a0, $t6
  sw $ra, 0($sp)
  addi $sp, $sp, -4
  jal write
  addi $sp, $sp, 4
  lw $ra, 0($sp)
label5:
label2:
  li $t7, 0
  move $v0, $t7
  jr $ra
