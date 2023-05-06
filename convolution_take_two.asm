
		.data

h_buf:  	.space   54
fname: 		.asciz  "projekt_riscv/pepsi.bmp"
output_name:	.asciz "projekt_riscv/convolres.bmp"

filter: 	.byte 1, 4, 6, 4, 1, 4, 16, 24, 16, 4, 6, 24, 36, 24, 6, 4, 16, 24, 16, 4, 1, 4, 6, 4, 1
#filter: 	.byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, -1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
#filter: 	.byte 0, 0, 0, 0, 0, 0, 0, -1, 0, 0, 0, -1, 4, -1, 0, 0, 0, -1, 0, 0, 0, 0, 0, 0, 0
#filter:		.byte 0, 0, -2, 0, 0, 0, -2, -5, -2, 0, -2, -5, 86, -5, -2, 0, -2, -5, -2, 0, 0, 0, -2, 0, 0
#filter:		.byte 0, 0, 0, 0, 0, 0, -1, 0, 1, 0, 0, -2, 0, 2, 0, 0, -1, 0, 1, 0, 0, 0, 0, 0, 0
#filter:		.byte 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
	   
	
 	       	.text
       	 	.globl  main

main:

get_file_desc:		# saves the file descriptor to a0
	li a7, 1024
	la a0, fname
    	li a1, 0
	ecall	
		
	mv s1, a0	# save the file descriptor

read_header:		# reads the first 54 bits of the file
	li a7, 63
	mv a0, s1	# might delete later
	la a1, h_buf
	li a2, 54	# only read 54 bytes
	ecall		# header stored in memory under h_buf
	
	
store_important_header_params:	# width stored in s10, height in s11
	la t0, h_buf		# offset of the rest of the file in s2
				# total size in s3
				# bytes 11-14 of the header - offset
	lhu s2, 12(t0)		# load offset into register
	slli s2, s2, 16		# make space for the rest of the offset
	lh t1, 10(t0)		# second half of the offset
	add s2, s2, t1		# add the halves together - offset in s2

	lhu s3, 4(t0)		# first half of size
	slli s3, s3, 16
	lh t1, 2(t0)
	add s3, s3, t1		# second half of size

				# bytes 19-22 - width
	lhu s4, 20(t0)		# first half of width
	slli s4, s4, 16		# make place for the other half
	lh t1, 18(t0)		# second half of width
	add s4, s4, t1		# add the halves together

				# bytes 23-26 - height
	lhu s5, 24(t0)		# load height into register
	slli s5, s5, 16		# make place again
	lh t1, 22(t0)
	add s5, s5, t1
	
	rem s8, s2, 4		# used to calculate the padding later on
	
	
allocate_memory_for_new_file:
	# This will be the buffer to write the convoluted pixels to
	li a7, 9
	mv a0, s3		# allocate memory for a whole copy of the file
	
	ecall
	mv s6, a0		# address of data block in s6



allocate_memory_for_pixels_only:
	# This will be the buffer to read pixels from and convolute them
	li a7, 9
	mv a0, s3		# allocate memory for a whole copy of the file
	sub a0, a0, s2		# we don't need the offset
	
	ecall
	mv s7, a0		# address of data block in s7
				
				
read_pixels:
	li a7, 62
	mv a0, s1		# seek to the start of pixel data
	mv a1, s2		
	mv a2, zero
	ecall
	
	li a7, 63		#  read the pixel data
	mv a0, s1
	mv a1, s7	
	
	mv a2, s3
	sub a2, a2, s2		# size - offset = size of pixel data
	
	ecall		
	
	
write_header_and_offset:
	li a7, 62
	mv a0, s1		# seek to the beginning of the file
	mv a1, zero		
	mv a2, zero
	ecall

	li a7, 63
	mv a0, s1		# file descriptor
	mv a1, s6		# address of memory block
	mv a2, s2		# file size to read - just the header + rest of the offset
	ecall
	
	
close_file:
	li a7, 57
	mv a0, s1
	ecall			# close the original bmp image


convolute_all_pixels:
	li s10, 0		# offset of current pixel in respect to the start of the pixel data
	
main_loop:
	sub t0, s3, s2		# size of pixel data in bytes
	bge s10, t0, end	# reached the end of the file
	
	mv a0, s10
	jal calculate_pixel_x
	mv a2, a1		# x of currently calculated pixel in a2
	
	mv a0, s10
	jal calculate_pixel_y
	mv a3, a1		# y of currently calculated pixel in a3	
	
	mv a6, zero		# register holding the sum of weights
	mv a7, zero		# register holding the sum of the B channel
	mv s0, zero		# register holding the sum of the G channel
	mv s1, zero		# register holding the sum of the R channel 
	
	
calculate_pixel_value:
	# starting offset parameters:
	li t0, -2				# current x offset in respect to the pixel being calculated
	li t1, -2				# current y offset in respect to the pixel being calculated	


validate_pixel:
	add a4, a2, t0				# x coordinate of the current surrounding pixel 
	bltz a4, next_pixel			# x too low - pixel out of the picture
	bge a4, s4, next_pixel			# x too high - pixel out of the picture
	
	add a5, a3, t1				# x coordinate of the current surrounding pixel
	bltz a5, next_pixel			# y too low - pixel out of the picture
	bge a5, s5, next_pixel			# y too high - pixel out of the picture
	
	
validated:
	
	# calculate the offset from the start of the filter and store the result in a2
	slli t2, t1, 2
	add t2, t2, t1				# multiply y offset * 5	
	add t2, t2, t0				# add x offset
	addi t2, t2, 12				# add 12 - we want the offset in the range 0->24, not -12->12
	
	# load the corresponding weight from memory
	la t3, filter
	add t2, t2, t3		# address of the weight
	lb t2, (t2)		# weight in t2
	add a6, a6, t2		# add weight to the sum of weights

	# load the color data from memory
	jal cords_to_offset	# calculate the offset of the byte from the start of the data
	add a1, a1, s7		# offset + address of start of data = address of the pixel
	
	# update the channel sums
	lbu t3, (a1)		# B channel
	mul t3, t3, t2		# mul by weight
	add a7, a7, t3		# add to channel sum
	
	lbu t3, 1(a1)		# G channel
	mul t3, t3, t2		# mul by weight
	add s0, s0, t3		# add to channel sum
	
	lbu t3, 2(a1)		# B channel 
	mul t3, t3, t2		# mul by weight
	add s1, s1, t3		# add to channel sum
	
		
				
	nop			# VALIDATED PIXEL
	
	
next_pixel:
	addi t0, t0, 1
	li t3, 2				# max offset
	bgt t0, t3, next_row			# x offset > 2 -> switch to next row
	b validate_pixel
	

next_row:
	li t0, -2				# reset the x offset
	addi t1, t1, 1				# one row down
	li t3, 2				# max offset
	bgt t1, t3, all_surr_pixels_looped	# y offset >=3 -> all pixels accounted for
	b validate_pixel



all_surr_pixels_looped:
	
	beqz a6, skip_division	# for filters where values sum up to 0

	# divide all channels by the sum of weights to normalize	
	div a7, a7, a6
	div s0, s0, a6
	div s1, s1, a6
	
skip_division:
	
	# calculate the offset to write under
	mv a4, a2
	mv a5, a3	
	
	call cords_to_offset
	add a1, a1, s6				# add base address to offset
	add a1, a1, s2				# add header + starting offset length to address
	
	# write the modified colors
	sb a7, (a1)
	sb s0, 1(a1)
	sb s1, 2(a1)		
	
	nop					# //MAIN PIXEL LOOP
	addi s10, s10, 3			# move 1 pixel = 3 bytes forward
	b main_loop


end:
	jal save_file
	li a7, 10
	ecall

	

save_file:
	li a7, 1024
	la a0, output_name
	li a1, 1
	ecall
	mv s1, a0
	
	li a7, 64
	mv a0, s1
	mv a1, s6
	mv a2, s3
	ecall
	ret


###################################################################3


calculate_pixel_x:
# calculates the x coordinate of the pixel in the cartesian coordinate system
# takes in the pixel offset in bytes in a0, returns the x value in a1
	li t0, 3
	divu t1, a0, t0		# index of the pixel
	remu a1, t1, s4		# x coordinate
	ret

calculate_pixel_y:
# calculates the y coordinate of the pixel in the cartesian coordinate system
# takes in the pixel offset in bytes in a0, returns the y value in a1
	li t0, 3
	divu t1, a0, t0		# index of the pixel
	divu a1, t1, s4		# y coordinate
	ret


cords_to_offset:
# calculates the offset of a pixel based on its x and y position
# takes in x in a4 and y in a5, returns offset in a1
				# MOD 4 CASE!
	slli t3, s4, 1		# multiply width of image by 3 to calculate width in pixels
	add t3, t3, s4		
	
	mul a1, t3, a5		# width in pixels * y = idx of start of row
	
	slli t3, a4, 1		# multiply x by 3 to calculate offset from start of row in pixels
	add t3, t3, a4		
	
	add a1, a1, t3		# add them together to get the final offset
	ret

#####################################################################


unit_tests:
	li a4, 3
	li a5, 3
	jal cords_to_offset
	li a7, 81
	bne a7, a1, test_failed
	nop	# FIRST TEST
	
	li a4, 0
	li a5, 7
	jal cords_to_offset
	li a7, 168
	bne a7, a1, test_failed
	nop	# 2ND TEST
	
	li a4, 0
	li a5, 0
	jal cords_to_offset
	mv a7, zero
	bne a7, a1, test_failed
	nop	# 3RD TEST
	
	li a4, 0
	li a5, 1
	jal cords_to_offset
	li a7, 24
	bne a7, a1, test_failed
	nop	# 4TH TEST
	
	
	b end


test_failed:
	nop



