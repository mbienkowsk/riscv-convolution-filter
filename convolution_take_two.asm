
		.data

h_buf:  	.space   54
fname: 		.asciz  "projekt_riscv/gnioblin.bmp"
output_name:	.asciz "projekt_riscv/gnioblin_out.bmp"

#filter: 	.byte 1, 4, 6, 4, 1, 4, 16, 24, 16, 4, 6, 24, 36, 24, 6, 4, 16, 24, 16, 4, 1, 4, 6, 4, 1
#filter: 	.byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, -1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
#filter: 	.byte 0, 0, 0, 0, 0, 0, 0, -1, 0, 0, 0, -1, 4, -1, 0, 0, 0, -1, 0, 0, 0, 0, 0, 0, 0
#filter:		.byte 0, 0, -2, 0, 0, 0, -2, -5, -2, 0, -2, -5, 86, -5, -2, 0, -2, -5, -2, 0, 0, 0, -2, 0, 0
filter:		.byte 0, 0, 0, 0, 0, 0, -1, 0, 1, 0, 0, -2, 0, 2, 0, 0, -1, 0, 1, 0, 0, 0, 0, 0, 0
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
	lhu t1, 10(t0)		# second half of the offset
	add s2, s2, t1		# add the halves together - offset in s2

	lhu s3, 4(t0)		# first half of size
	slli s3, s3, 16
	lhu t1, 2(t0)
	add s3, s3, t1		# second half of size

				# bytes 19-22 - width
	lhu s4, 20(t0)		# first half of width
	slli s4, s4, 16		# make place for the other half
	lhu t1, 18(t0)		# second half of width
	add s4, s4, t1		# add the halves together

				# bytes 23-26 - height
	lhu s5, 24(t0)		# load height into register
	slli s5, s5, 16		# make place again
	lhu t1, 22(t0)
	add s5, s5, t1
	
	li t1, 4
	rem s8, s4, t1		# used to calculate the padding later on

	
	
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
	
	jal normalize_rgb_values
		
	
	# calculate the offset to write under
	mv a4, a2
	mv a5, a3	
	
	jal cords_to_offset
	add a1, a1, s6				# add base address to offset
	add a1, a1, s2				# add header + starting offset length to address
	
	# write the modified colors
	sb a7, (a1)
	sb s0, 1(a1)
	sb s1, 2(a1)		
	nop					# //MAIN PIXEL LOOP
	
	mv t6, a1				# save in case end of row is reached
	
	addi s10, s10, 3			# move 1 pixel = 3 bytes forward
	mv a0, s10
	
	jal calculate_pixel_x
	blt a1, s4, main_loop			# not the last pixel in row
	
	add s10, s10, s8			# last pixel in row - skip the padding
	mv t5, s8				# copy of padding size
	addi t6, t6, 3				# first free address
	
	write_padding_loop:
		beqz t5, main_loop		# all padding has been redistributed
		sb zero, (t6)			# pad
		addi t6, t6, 1			# increment writing address
		addi t5, t5, -1			# decrement loops left counter
		b write_padding_loop
		#//changed

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


###################################################################


calculate_pixel_x:
# calculates the x coordinate of the pixel in the cartesian coordinate system
# takes in the pixel offset in bytes in a0, returns the x value in a1
	li t0, 3		#//changed
	mul t1, s4, t0
	add t1, t1, s8		# width of the file in bytes
	remu a1, a0, t1		# x idx of byte in row
	divu a1, a1, t0		# divide by 3 to get the index of the pixel
	ret

calculate_pixel_y:
# calculates the y coordinate of the pixel in the cartesian coordinate system
# takes in the pixel offset in bytes in a0, returns the y value in a1
	li t0, 3		#//changed
	mul t1, s4, t0
	add t1, t1, s8		# width of the file in bytes

	divu a1, a0, t1		# y coordinate
	ret


cords_to_offset:
# calculates the offset of a pixel based on its x and y position
# takes in x in a4 and y in a5, returns offset in a1
				#//changed
	slli t3, s4, 1		# multiply width of image by 3 to calculate width in pixels
	add t3, t3, s4		
	add t3, t3, s8		# account for zero-padding if width mod 4!=0
	
	mul a1, t3, a5		# width in pixels * y = idx of start of row
	
	slli t3, a4, 1		# multiply x by 3 to calculate offset from start of row in pixels
	add t3, t3, a4		
	
	add a1, a1, t3		# add them together to get the final offset
	ret


normalize_rgb_values:
# normalizes the rgb values so that values < 0 are interpreted as 0
# and values greater than 255 are interpreted as 255
# takes in the weighted sums from s0, s1 and a7 and modifies them if needed
	
	li t1, 255	# max val
		bgt a7, t1, b_to_255
		bltz a7, b_to_0
	normalize_green:
		bgt s0, t1, g_to_255
		bltz s0, g_to_0
	normalize_red:
		bgt s1, t1, r_to_255
		bltz s1, r_to_0
	ret
	
	b_to_255:
		li a7, 255
		b normalize_green
		
	b_to_0:
		li a7, 0
		b normalize_green

	g_to_255:
		li s0, 255
		b normalize_red
		
	g_to_0:
		li s0, 0
		b normalize_red
		
	r_to_255:
		li s1, 255
		ret
	r_to_0:
		li s1, 0
		ret
	
	

#####################################################################


unit_tests:

	li a0, 24
	li s4, 7
	li s8, 3
	
	jal calculate_pixel_y
	li a7, 1
	bne a7, a1, test_failed
	nop	# FIRST TEST
	
	li a0, 19
	li s4, 6
	li s8, 2
	
	jal calculate_pixel_y
	li a7, 0
	bne a7, a1, test_failed
	nop	# 2ND TESTT
	
	li a0, 19
	li s4, 5
	li s8, 3
	
	jal calculate_pixel_y
	li a7, 1
	bne a7, a1, test_failed
	nop	# 3RD TESTT
	
	li a0, 93
	li s4, 7
	li s8, 1
	
	jal calculate_pixel_y
	li a7, 4
	bne a7, a1, test_failed
	nop	# 4TH TESTT
	
	
	b end




test_failed:
	nop



