
	.data

h_buf:  .space   54
fname: 	.asciz  "projekt_riscv/czumpee2.bmp"
filter: .byte 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 	
	   
	
        .text
        .globl  main


main:



get_file_desc:		# saves the file descriptor to a0
	li a7, 1024
	la a0, fname
    	li a1, 0
	ecall	
		
	mv s2, a0	# save the file descriptor

read_header:		# reads the first 54 bits of the file
	li a7, 63
	mv a0, s2	# might delete later
	la a1, h_buf
	li a2, 54	# only read 54 bytes
	ecall		# header stored in memory under h_buf


store_important_header_params:	# width stored in s10, height in s11
	la t1, h_buf		# offset of the rest of the file in s9
				# total size in s8
				# bytes 11-14 of the header - offset
	lhu s9, 12(t1)		# load offset into register
	slli s9, s9, 16		# make space for the rest of the offset
	lh t2, 10(t1)		# second half of the offset
	add s9, s9, t2		# add the halves together - offset in s9

	lhu s8, 4(t1)		# first half of size
	slli s8, s8, 16
	lh t2, 2(t1)
	add s8, s8, t2		# second half of size

				# bytes 19-22 - width
	lhu s10, 20(t1)		# first half of offset
	slli s10, s10, 16	# make place for the other half
	lh t2, 18(t1)		# second half of offset
	add s10, s10, t2	# add the halves together

				# bytes 23-26 - height
	lhu s11, 24(t1)		# load height into register
	slli s11, s11, 16	# make place again
	lh t2, 22(t1)
	add s11, s11, t2


allocate_memory_for_new_file:
	li a7, 9
	mv a0, s8		# allocate memory for a whole copy of the file
	
	ecall
	mv s7, a0		# address of data block in s7


read_contents_from_file:
	li a7, 62
	mv a0, s2		# seek to the beginning of the file
	mv a1, zero		
	mv a2, zero
	ecall

	li a7, 63
	mv a0, s2		# file descriptor
	mv a1, s7		# address of memory block
	mv a2, s8		# file size to read
	ecall
	

allocate_memory_for_padded_img:
	addi t1, s10, 4		# 2 pixels of padding on each side
	addi t2, s11, 4	
	mul t3, t1, t2		# num of pixels with padding
	slli a0, t3, 1		
	add a0, a0, t3		# num of pixels * 3 in a0
	
	li a7, 9
	ecall
	mv s6, a0		# address of the padded block in s6

pad_img:
	# Pads the memory in a0 with 2 rows and 2 cols of zero-filled pixels
	addi t1, s10, 4		# row size
	addi t2, s11, 4		# column size

	mv a0, t1		# start of the block
	mv a1, s7		# row size
	
	# First two rows
	call set_x_pixels_to_0
	call set_x_pixels_to_0
		

exit:
    li a7, 10
    ecall


set_x_pixels_to_0:
	# takes in a number of pixels to set in a0 and an address to write under in a1
	# sets the specified number of pixels (24 byte blocks) to 0 and increments the address in a1
	# by the number of bytes overwritten
	slli t3, a0, 1		# 3*pixels bytes to write
	add t3, t3, a0
set_to_0_loop:
	beqz t3, return		# all the pixels were set
	addi t3, t3, -1		# decrement the number of bytes to write
	sb zero, (a1)		
	addi a1, a1, 1		# increment the writing address
	b set_to_0_loop
return:
	ret