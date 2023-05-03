
		.data

h_buf:  	.space   54
fname: 		.asciz  "projekt_riscv/czumpee2.bmp"
output_name:	.asciz "projekt_riscv/convol_result.bmp"
filter: 	.byte 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 	
	   
	
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
	# This will be the buffer to write the convoluted pixels to
	li a7, 9
	mv a0, s8		# allocate memory for a whole copy of the file
	
	ecall
	mv s7, a0		# address of data block in s7


allocate_memory_for_pixels_only:
	# This will be the buffer to read pixels from and convolute them
	li a7, 9
	mv a0, s8		# allocate memory for a whole copy of the file
	sub a0, a0, s9		# we don't need the offset
	
	ecall
	mv s6, a0		# address of data block in s6
				

read_pixels:
	li a7, 62
	mv a0, s2		# seek to the start of pixel data
	mv a1, s9		
	mv a2, zero
	ecall
	
	li a7, 63		#  read the pixel data
	mv a0, s2
	mv a1, s6	
	
	mv a2, s8
	sub a2, a2, s9		# size - offset = size of pixel data
	
	ecall		

	
write_header_and_offset:
	li a7, 62
	mv a0, s2		# seek to the beginning of the file
	mv a1, zero		
	mv a2, zero
	ecall

	li a7, 63
	mv a0, s2		# file descriptor
	mv a1, s7		# address of memory block
	mv a2, s9		# file size to read - just the header + rest of the offset
	ecall
	
close_file:
	li a7, 57
	mv a0, s2
	ecall			# close the original bmp image

	
applyFilter:
	# applies the filter to all pixels and saves them to the s7 buffer
	# s6 is the reading address - the pixel, the value of which is currently being calculated
		
	add s5, s7, s9		# writing address that will be updated throughout the function
	mv s2, s6		# a copy of the block address, so we can modify the s6 one as we progress
	
	value_for_each_pixel:
		add t2, s7, s8			# the end address of our writing block - if we reach it, the filter is applied
		bge s5, t2, end			# all the data is ready, save the file and end the program
		
		b calculate_pixel_value
		
	return_address_from_CPV:
		addi s6, s6, 3			# next pixel
		b value_for_each_pixel		# loop over
	
	
calculate_pixel_value:
	# calculates the new value of a given pixel
	# params: pixel address in s6
	# no return value, saves the pixels under the writing address
	# pixel A - the pixel, the value of which is calculated
	# pixel B - the pixel around it which is currently summed
	
	mv a1, s6		# calculate x of the pixel
	jal calculate_pixel_x
	mv a2, a7		# keep the x of the pixel for the whole iteration
	
	mv t6, zero		# the register for holding the weighted sum - R channel
	mv t5, zero		# the register for holding the weighted sum - G channel
	mv t4, zero		# the register for holding the weighted sum - B channel 
	
	mv t3, zero		# the register for holding the sum of weights
	mv s3, zero		# the offset in respect to the filter - which weight to apply to each pixel
	
	li a6, -2		# the currently examined row offset
	li a5, -2		# currently examined col offset
	
	
	addi t1, s6, -2		# two pixels to the left
	slli t2, s10, 1		# two rows up
	not t2, t2	
	addi t2, t2, 1		# sign inversion
	add a1, t1, t2		# the address of the furthest pixel up to the left - the first one to convolve
	li t1, 2		# max row and col offset
	
	
	loop_over_pixels:
		li t1, 2	# max row and col offset
		bgt a5, t1, next_row
		
	validate_x:
		call calculate_pixel_x
		sub a2, a2, a7	# difference between the x cords
	
		bgt a2, t1, skip_pixel	# too big of a difference - edge pixel
	
		li t1, -2
		blt a2, t1, skip_pixel	# too small of a difference - edge pixel
		
	validate_y:
		call calculate_pixel_y
	
		bltz a2, skip_pixel	# y below 0 -> data from outside the image
		bge a2, s11, skip_pixel	# y >= height -> data from outside the image

	validated:
		la t2, filter
		add t2, t2, s3		# address of the current filter weight
		lb t2, (t2)		# load the weight
		add t3, t3, t2		# add it to the current sum of weights
		
		lb t1, (a1)		# R channel
		mul t1, t1, t2		# value * weight
		add t6, t6, t1		# add up to the sum
		
		addi a1, a1, 1		# G channel
		lb t1, (a1)
		mul t1, t1, t2		
		add t5, t5, t1
		
		addi a1, a1, 1		# B channel
		lb t1, (a1)
		mul t1, t1, t2		
		add t4, t4, t1
		
		addi a5, a5, 1		# update the x offset before moving to the next pixel
		addi s3, s3, 1		# move to the next weight
		b loop_over_pixels	# move to the next pixel - its address is already in a1
						

	skip_pixel:
		# move to the next pixel without adding its value to the weighted sums
		addi s3, s3, 1		# move to the next weight
		addi a1, a1, 3		# move 3 bytes to the right - to the next pixel
		addi a5, a5, 1		# update the x offset
		b loop_over_pixels
		
		
	next_row:
		addi a6, a6, 1	# move to next row
		li a5, -2	# reset the x offset	

		add a1, a1, s10	# the same thing, but with the address
		addi a1, a1, -2
		
		li t1, 2
		bgt a6, t1, all_pixels_looped
		b loop_over_pixels
		

	all_pixels_looped:
		# divide the sums by the sum of weights and write them under the address
		div t6, t6, t3
		div t5, t5, t3
		div t4, t4, t3
		
		sb t6, (s5)
		addi s5, s5, 1
		sb t5, (s5)
		addi s5, s5, 1
		sb t4, (s5)
		addi s5, s5, 1
		b return_address_from_CPV # return from the function
	
	
end:
	call save_file
	li a7, 10
	ecall



calculate_pixel_x:
	# calculates the x coordinate of a pixel's location in on a plane where the left most pixel has coordinates (0,0)
	# params: pixel address in a1
	# returns: pixel x in a2
	sub a2, a1, s2		# calculate the index of the pixel in the image
	rem a2, a2, s10		# divide by row size and get the remainder - that's the x cord of the byte
	li t2, 3
	div a2, a2, t2		# pixel coordinate -> divide by 3
	ret
	

calculate_pixel_y:
	# calculates the x coordinate of a pixel's location in on a plane where the left most pixel has coordinates (0,0)
	# params: pixel address in a1
	# returns: pixel x in a2
	sub a2, a1, s2		# index of the pixel in the imag3
	div a2, a2, s10		# divide and get y cord of the byte
	li t2, 3
	div a2, a2, t2		# pixel coordinate -> divide by 3
	ret
	



save_file:
	li a7, 1024
	la a0, output_name
	li a1, 1
	ecall
	mv s1, a0
	
	li a7, 64
	mv a0, s1
	mv a1, s7
	mv a2, s8
	ecall
	ret
			





