.global return_char
return_char:
	subi sp,sp,4
	stw r8,0(sp)
 
	addi r8,r0,1
	beq r4,r8,one
 
	addi r8,r0,2
	beq r4,r8,two
 
	addi r8,r0,3
	beq r4,r8,three
 
	addi r8,r0,4
	beq r4,r8,four
 
	addi r8,r0,5
	beq r4,r8,five
 
	addi r8,r0,6
	beq r4,r8,six
 
	addi r8,r0,6
	bgt r4,r8,three
 
one:
	addi r2,r0,4
	br end

two:
	addi r2,r0,1
	br end

three:
	addi r2,r0,2
	br end

four:
	addi r2,r0,6
	br end

five:
	addi r2,r0,3
	br end

six:
	addi r2,r0,5
	br end

end:
	ldw r8,0(sp)
	addi sp,sp,4
ret