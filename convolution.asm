
           .data

h_buf:     .space   54
fname:     .asciz  "projekt_riscv/czumpee2.bmp"

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
				# bytes 11-14 of the header - offset
	lhu s9, 12(t1)		# load offset into register
	slli s9, s9, 16		# make space for the rest of the offset
	lh t2, 10(t1)		# second half of the offset
	add s9, s9, t2		# add the halves together - offset in s9

				# bytes 19-22 - width
	lhu s10, 20(t1)		# first half of offset
	slli s10, s10, 16	# make place for the other half
	lh t2, 18(t1)		# second half of offset
	add s10, s10, t2		# add the halves together

				# bytes 23-26 - height
	lhu s11, 24(t1)		# load height into register
	slli s11, s11, 16	# make place again
	lh t2, 22(t1)
	add s11, s11, t2

exit:
    li a7, 10
    ecall


