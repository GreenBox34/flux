# bit -- Simple Brainfuck Interpreter.
#
# GPL v3+
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

.macro NEXT
	inc %rsi # increment %rsi
	jmp parse
.endm

.global _start
.text
_start:
	movq (%rsp), %rdx # mov argc to %rdx

	cmp $0x01, %rdx # if %rdx <= 1 jmp to input_program
	jle input_program

	mov $0x02, %rax # sys_open
	movq 0x10(%rsp), %rdi # move argv[1] in %rdi this should a pointer to the filename
	mov $0x00, %rsi # flag
	mov $0x00, %rdx # mode
	syscall

	mov %rax, %r15 # save fd in %rax return by sys_open

	mov $0x00, %rax # sys_read
	movq %r15, %rdi # move fd saved in %r15 to %rdi
	lea program(%rip), %rsi # pointer to program buffer
	mov $200000, %rdx # size of program buffer
	syscall

	mov $0x03, %rax # sys_close
	mov %r15, %rdi # fd to close
	syscall

	jmp flux

input_program:
	mov $0x00, %rax	# read syscall number
	mov $0x00, %rdi	# file discriptor 0 for stdin
	lea program(%rip), %rsi # pointer to program buffer
	mov $200000, %rdx # size of program buffer DEC: 30000 bytes
	syscall

flux:
	lea tape + 1000(%rip), %rdx # start the data pointer 1000 cells from the start
	lea loop_stack(%rip), %r10 # pointer to loop_stack

parse:
	movb (%rsi), %r12b # move 1 byte from program in %r12b

	cmpb $0x3e, %r12b # >
	je right

	cmpb $0x3c, %r12b # <
	je left

	cmpb $0x2b, %r12b # +
	je increment

	cmpb $0x2d, %r12b # -
	je decrement

	cmpb $0x2e, %r12b # .
	je output

	cmpb $0x2c, %r12b # ,
	je input

	cmpb $0x5b, %r12b # [
	je loop_start

	cmpb $0x5d, %r12b # ]
	je loop_end

	cmpb $0x00, %r12b
	je exit

	NEXT
exit:
	mov $0x3c, %rax # exit syscall number HEX: 0x3c DEC: 60
	mov $0x00, %rdi	# exit code
	syscall

right: # >
	inc %rdx # decrement tape by one
	NEXT # get next instruction

left: # <
	dec %rdx # increment tape by one
	NEXT # get next instruction

increment: # +
	movb (%rdx), %bl # move current cell value in %dl
	addb $0x01, %bl  # add 1 to it
	movb %bl, (%rdx) # move the value back to the current cell
	NEXT # get next instruction

decrement: # -
	movb (%rdx), %bl # move current cell value in %dl
	subb $0x01, %bl  # substract current cell by one
	movb %bl, (%rdx) # move the value back to the current cell
	NEXT # get next instruction

input: # ,
	xor %r13, %r13 # clear %r13
	movq %rdx, %r14 # move current tape pointer in %r14
	movq %rsi, %r15 # move current program pointer in %r15

	mov $0x00, %rax	# read syscall number
	mov $0x00, %rdi	# file discriptor 0x00 for stdin
	lea tmp(%rip), %rsi # pointer to tmp buffer save one byte
	mov $0x01, %rdx	 # size of tmp buffer 0x01 byte
	syscall

	movq %r14, %rdx # move tape pointer back to %rdx

	movb (%rsi), %r13b # save read byte in tmp buffer to %r13b
	movb %r13b, (%rdx) # save read byte in %r13b to current cell

	movq %r15, %rsi # move program pointer back to %rsi
	NEXT # get next instruction

output: # .
	movq %rdx, %r14 # move current data pointer in %r14
	movq %rsi, %r15 # move current instruction pointer in %r15

	movb (%rdx), %al # move current byte %rdx points to, to %r13b
	lea tmp(%rip), %rcx # pointer to tmp buffer
	movb %al, (%rcx) # move byte saved in %r13b to tmp

	mov $0x01, %rax	# read syscall number
	mov $0x01, %rdi	# file discriptor 0x00 for stdout
	mov %rcx, %rsi
	mov $0x01, %rdx	 # size of tmp buffer 0x01 byte
	syscall

	movq %r14, %rdx # move data pointer back to %rdx
	movq %r15, %rsi # move instruction pointer back to %rsi
	NEXT # get next instruction

loop_start: # [
	cmpb $0x00, (%rdx) # if current data pointer is zero skip loop
	jz .skip

	mov %rsi, (%r10) # move current address at %rsi in %r10 (loop_stack)
	add $0x08, %r10 # move %r10 0x08 up
	NEXT # get next instruction

	.skip:
		xor %r13, %r13 # clear %rcx
		inc %r13 # increment %r13
		jmp skip_loop

loop_end: # ]
	cmpb $0x00, (%rdx) # if data pointer zero finish loop
	jz .loop_finished

	mov -0x08(%r10), %rsi # got back to address [
	NEXT # get next instruction

	.loop_finished:
		sub $0x08, %r10 # sub 0x08 pop address
		NEXT # get next instruction

skip_loop:
	inc %rsi # incremnt %rsi get next instruction

	cmpb $0x5b, (%rsi) # [
	je .inc_rcx

	cmpb $0x5d, (%rsi) # ]
	je .dec_rcx

	jmp skip_loop

	.inc_rcx:
		inc %r13 # increment %r13
		jmp skip_loop
	.dec_rcx:
		dec %r13 # increment %r13
		jnz skip_loop # if %r13 not zero we are still in a loop
		NEXT # get next instruction
.bss
	.lcomm tape, 30000
	.lcomm program, 200000
	.lcomm loop_stack, 1024
	.lcomm tmp, 1
