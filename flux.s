/* flux -- Brainfuck Interpreter. */

/*
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

.data
	.equ TAPE_SIZE, 32000
	.equ SYS_READ,  0
	.equ SYS_WRITE, 1
	.equ SYS_OPEN,  2
	.equ SYS_CLOSE, 3
	.equ SYS_FSTAT, 5
	.equ SYS_MMAP,  9
.bss
	.lcomm statbuf, 144
	.lcomm tmp, 1

/* macro definitions */
.macro NEXT
	inc %rsi
	jmp parse
.endm

.macro EXIT Code
	mov $60, %rax
	mov $\Code, %rdi
	syscall
.endm

.macro check_syscall_error
	cmp $0, %rax # if %rax < 0 EXIT
	jl EXIT_FAILURE
.endm
/* end macro definitions */

.global _start
.text
_start:
	pop %rdx # pop argc from the stack

	cmp $1, %rdx # if %rdx <= 1
	jg read_program

	mov $512, %rbx # bytes to allocate

	mov $SYS_MMAP, %rax
	xor %rdi, %rdi # address zero kernel choses
	mov %rbx, %rsi # length
	mov $0x03, %rdx # PROT_READ|PROT_WRITE
	mov $0x22, %r10 # MAP_PRIVATE|MAP_ANONYMOUS
	mov $-1, %r8 # file discriptor -1 for none
	xor %r9, %r9 # offset 0
	syscall

	check_syscall_error

	movq %rax, %r14 # save memory map returend by mmap

	mov $SYS_READ, %rax
	mov $0, %rdi	# file discriptor 0 for stdin
	movq %r14, %rsi # memory map allocated by mmap
	mov %rbx, %rdx # len
	syscall

	check_syscall_error

	jmp alloc_tape

read_program:
	pop %rdi # pop argv[0] from the stack

	mov $SYS_OPEN, %rax
	pop %rdi # pop argv[1] first argument
	mov $0x00, %rsi # flag
	mov $0x00, %rdx # mode
	syscall

	check_syscall_error

	mov %rax, %r15 # save file discriptor returned by sys_open

	mov $SYS_FSTAT, %rax
	mov %r15, %rdi # file discriptor
	lea statbuf, %rsi
	syscall

	check_syscall_error

	lea statbuf(%rip), %rax # pointer stat structure
	movq 48(%rax), %rbx # save file size
	add $1, %rbx

	# allocate memory the program
	mov $SYS_MMAP, %rax
	xor %rdi, %rdi # address zero kernel choses
	mov %rbx, %rsi # length (file size)
	mov $0x03, %rdx # PROT_READ|PROT_WRITE
	mov $0x22, %r10 # MAP_PRIVATE|MAP_ANONYMOUS
	mov $-1, %r8 # file discriptor -1 for none
	xor %r9, %r9 # offset 0
	syscall

	check_syscall_error

	mov %rax, %r14 # save program

	mov $SYS_READ, %rax
	movq %r15, %rdi # move file descriptor saved in %r15 to %rdi
	movq %r14, %rsi # read the program in memory map
	mov %rbx, %rdx # size of allocated bytes
	syscall

	check_syscall_error

	mov $SYS_CLOSE, %rax
	mov %r15, %rdi # file descriptor to close
	syscall

	check_syscall_error

alloc_tape:
	# allocate memory for tape
	mov $SYS_MMAP, %rax
	xor %rdi, %rdi # address zero kernel choses
	mov $TAPE_SIZE, %rsi # length
	mov $0x03, %rdx # PROT_READ|PROT_WRITE
	mov $0x22, %r10 # MAP_PRIVATE|MAP_ANONYMOUS
	mov $-1, %r8 # file discriptor -1 for none
	xor %r9, %r9 # offset 0
	syscall

	check_syscall_error

	movq %rax, %rdx # save the tape pointer to %rdx
	movq %r14, %rsi # program pointer to %rsi

parse:
	movb (%rsi), %r12b

	cmpb $'>', %r12b
	je right

	cmpb $'<', %r12b
	je left

	cmpb $'+', %r12b
	je increment

	cmpb $'-', %r12b
	je decrement

	cmpb $'.', %r12b
	je output

	cmpb $',', %r12b
	je input

	cmpb $'[', %r12b
	je loop_start

	cmpb $']', %r12b
	je loop_end

	cmpb $0, %r12b
	je EXIT_SUCCESS

	NEXT

right:
	call combine
	1:
		inc %rdx # increment tape by one
		loop 1b
	NEXT

left:
	call combine
	1:
		dec %rdx # decrement tape by one
		loop 1b
	NEXT

increment:
	call combine # number to increment in %cl
	movb (%rdx), %bl # current cell value in %dl
	addb %cl, %bl
	movb %bl, (%rdx) # value back to the current cell
	NEXT

decrement:
	call combine # number to decrement in %cl
	movb (%rdx), %bl # current cell value in %dl
	subb %cl, %bl
	movb %bl, (%rdx) # value back to the current cell
	NEXT

input:
	movq %rdx, %r14 # move current tape pointer in %r14
	movq %rsi, %r15 # move current program pointer in %r15

	mov $SYS_READ, %rax
	mov $0x00, %rdi	# file discriptor 0x00 for stdin
	lea tmp(%rip), %rsi # pointer to tmp buffer save one byte
	mov $0x01, %rdx	 # size of tmp buffer 1 byte
	syscall

	check_syscall_error

	movq %r14, %rdx # move tape pointer back to %rdx

	movb (%rsi), %r13b # save read byte in tmp buffer to %r13b
	movb %r13b, (%rdx) # save read byte in %r13b to current cell

	movq %r15, %rsi # move program pointer back to %rsi
	NEXT

output: # .
	movq %rdx, %r14 # move current data pointer in %r14
	movq %rsi, %r15 # move current instruction pointer in %r15

	movb (%rdx), %al # move current byte %rdx points to, to %r13b
	lea tmp(%rip), %rcx # pointer to tmp buffer
	movb %al, (%rcx) # move byte saved in %r13b to tmp

	mov $SYS_WRITE, %rax
	mov $0x01, %rdi	# file discriptor 0x00 for stdout
	mov %rcx, %rsi
	mov $0x01, %rdx	 # size of tmp buffer 0x01 byte
	syscall

	check_syscall_error

	movq %r14, %rdx # move data pointer back to %rdx
	movq %r15, %rsi # move instruction pointer back to %rsi
	NEXT

loop_start:
	cmpb $0, (%rdx) # if current data pointer is zero skip loop
	jz .skip_loop

	push %rsi # push return address on the stack
	NEXT

	.skip_loop:
		mov $0, %r13
		jmp 1f
	1:
		inc %rsi # get next instruction

		cmpb $'[', (%rsi)
		je .inc_r13

		cmpb $']', (%rsi)
		je .dec_r13

		jmp 1b

		.inc_r13:
			inc %r13
			jmp 1b
		.dec_r13:
			dec %r13
			jnz 1b # if %r13 not zero we are still in a loop
			NEXT

loop_end:
	cmpb $0, (%rdx) # if data pointer zero finish loop
	jz .loop_finished

	movq (%rsp), %rsi # return back to [

	NEXT

	.loop_finished:
		pop %r13 # pop return address
		NEXT

combine:
	xor %rcx, %rcx
	movb (%rsi), %r15b # save current instruction

	.loop:
		movb (%rsi), %r14b # save current instruction

		cmpb %r15b, %r14b # if %r15b not equal %r14b
		jne .return

		inc %cl # %cl as counter
		inc %rsi # get next instruction

	jmp .loop

	.return:
		dec %rsi # move one instruction back
		ret

EXIT_SUCCESS:
	EXIT 0

EXIT_FAILURE:
	EXIT 1
