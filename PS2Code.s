.include "nios_macros.s"

 .global CHARACTERS
.data
CHARACTERS_ps2:
	.skip 18  /* save space for 6 make-break-make code characters */
CHARACTERS:
	.skip 6  /* save space for 6 characters */


 .text
 .global read_ps2
read_ps2:
	addi sp, sp, -96
	stw r4, 0(sp)			# stores the address of where we want to draw
	stw r10, 4(sp)			# stores the width of the box
	stw r11, 8(sp)			# stores the length of the box
	stw r12, 12(sp)			# stores the old value of r4
	stw r13, 16(sp)			# stores the colour of the box
	stw r14, 20(sp)			# stores how many boxes have been drawn
	stw r15, 24(sp)			# stores how many boxes will be drawn per character
	stw r16, 28(sp)			# stores the top left coordinate of a box
	stw r17, 32(sp)			# stores the location of the pixel before the last pixel ( to draw empty squares )
	stw r18, 36(sp)			# stores where in the y axis increment we are.
	stw r19, 40(sp)			# stores how far down the box has to go (in linear increments rather than 1024)
	stw r20, 44(sp)			# stores how many character sets we're going to draw
	stw r21, 48(sp)			# stores how many characters sets have been drawn
	stw r5, 52(sp)			# used to draw the character on the screen
	stw r22, 56(sp)			# used to restore the location of r4 after every box
	stw r23, 60(sp)			# used to check the character array
	stw r24, 64(sp)
	stw r3, 68(sp)
	stw r4, 72(sp)
	stw r6, 76(sp)
	stw r7, 80(sp)
	stw r8, 84(sp)
	stw r9, 88(sp)
	stw ra, 92(sp)
	
	movia r3, 0x10000100 /* r7 now contains the base address */
	movia r6, CHARACTERS_ps2 /* r6 contains address of the string CHARACTERS */
	movia r11,CHARACTERS 

	addi r7,r0,0
	addi r8,r0,6  

  movui r16, 0xF0 /*Command to change mode of ps2`*/
  stwio r16, 0(r3) 
  add r17,r0,r0
DISCARD_COMMAND_OUTPUT1:
	ldwio r4, 0(r3) /* Load from the JTAG */
	andi  r5, r4, 0x8000 /* Check only the READ available bits */
	beq   r5, r0, WAIT_FOR_BYTE  /*If this is 0 (branch true), data cannot be read */ 
	ADD_1_TO_LOOP_COUNTER:
	addi r17,r17,1
	WAIT_FOR_BYTE:
	beq r17,r0, DISCARD_COMMAND_OUTPUT1

	
  movui r16, 0x03 /*Argument for the command above to set the mode to 3*/
  stwio r16, 0(r3)
   add r17,r0,r0
DISCARD_COMMAND_OUTPUT2:
	ldwio r4, 0(r3) /* Load from the JTAG */
	andi  r5, r4, 0x8000/* Check only the READ available bits */
	beq   r5, r0, WAIT_FOR_BYTE2  /*If this is 0 (branch true), data cannot be read */ 
	ADD_1_TO_LOOP_COUNTER2:
	addi r17,r17,1
	WAIT_FOR_BYTE2:
	beq r17,r0, DISCARD_COMMAND_OUTPUT2
  
  movui r16, 0xF9 /* writing DISABLE break codes && TYPEMATIC COMMAND TO ps2 keyboard */
  stwio r16, 0(r3)
   add r17,r0,r0
  DISCARD_COMMAND_OUTPUT3:
	ldwio r4, 0(r3) /* Load from the JTAG */
	andi  r5, r4, 0x8000/* Check only the READ available bits */
	beq   r5, r0, WAIT_FOR_BYTE3  /*If this is 0 (branch true), data cannot be read */ 
	ADD_1_TO_LOOP_COUNTER3:
	addi r17,r17,1
	WAIT_FOR_BYTE3:
	beq r17,r0, DISCARD_COMMAND_OUTPUT3
	
	add r17,r0,r0
  READ_CHAR:
	ldwio r4, 0(r3) /* Load from the JTAG */
	andi  r5, r4, 0x8000	 /* Check only the READ available bits */
	beq   r5, r0, WAIT_FOR_BYTE4  /*If this is 0 (branch true), data cannot be read */ 
	ADD_1_TO_LOOP_COUNTER4:
	addi r17,r17,1
	WAIT_FOR_BYTE4:
	beq r17,r0, READ_CHAR
	andi  r5, r4, 0x00FF /* Data read is now in r5 */
	stb r5,0(r6)   /* store byte of character in the array CHARACTERS */
	addi r6,r6,1   /* keep moving 1 position to the right in the array for the next byte */
	addi r7,r7,1 /* keep polling until 5 characters(10 bytes) are read */
	add r17,r0,r0
	bne r7,r8,READ_CHAR
	  
	addi r7,r0,0
	addi r8,r0,6
	movia r6, CHARACTERS_ps2

 CHAR_ARRAY:	
	ldb r9,0(r6)
	call DECODE_CHAR
	addi r6,r6,1
	addi r11,r11,1
	addi r7,r7,1 /* keep polling until 5 characters(10 bytes) are read */
    bne r7,r8,CHAR_ARRAY
	movia r11, CHARACTERS 

 EXIT:
	ldw r4, 0(sp)			
	ldw r10, 4(sp)			
	ldw r11, 8(sp)		
	ldw r12, 12(sp)			
	ldw r13, 16(sp)			
	ldw r14, 20(sp)			
	ldw r15, 24(sp)			
	ldw r16, 28(sp)			
	ldw r17, 32(sp)			
	ldw r18, 36(sp)			
	ldw r19, 40(sp)			
	ldw r20, 44(sp)			
	ldw r21, 48(sp)			
	ldw r5, 52(sp)			
	ldw r22, 56(sp)			
	ldw r23, 60(sp)			
	ldw r24, 64(sp)
	ldw r3, 68(sp)
	ldw r4, 72(sp)
	ldw r6, 76(sp)
	ldw r7, 80(sp)
	ldw r8, 84(sp)
	ldw r9, 88(sp)
	ldw ra, 92(sp)
	addi sp, sp, 96
	ret	

DECODE_CHAR:
	addi sp, sp, -20
	stw r9, 0(sp)
	stw r10, 4(sp)
	stw r11, 8(sp)
	stw r12, 12(sp)
	stw ra, 16(sp)
	
	addi r10, r0, 0x1C
	beq r10,r9,a
	
	addi r10, r0, 0x32
	beq r10,r9,b
	
	addi r10, r0, 0x21
	beq r10,r9,c
	
	addi r10, r0, 0x23
	beq r10,r9,d
	
	addi r10, r0, 0x24
	beq r10,r9,e
	
	addi r10, r0, 0x2B
	beq r10,r9,f
	
	addi r10, r0, 0x34
	beq r10,r9,g
	
	addi r10, r0, 0x33
	beq r10,r9,h
	
	addi r10, r0, 0x43
	beq r10,r9,i
	
	addi r10, r0, 0x3B
	beq r10,r9,j
	
	addi r10, r0, 0x42
	beq r10,r9,k
	
	addi r10, r0, 0x4B
	beq r10,r9,l
	
	addi r10, r0, 0x3A
	beq r10,r9,m
	
	addi r10, r0, 0x31
	beq r10,r9,n
	
	addi r10, r0, 0x44
	beq r10,r9,o
	
	addi r10, r0, 0x4D
	beq r10,r9,p
	
	addi r10, r0, 0x15
	beq r10,r9,q
	
	addi r10, r0, 0x2D
	beq r10,r9,r
	
	addi r10, r0, 0x1B
	beq r10,r9,s
	
	addi r10, r0, 0x2C
	beq r10,r9,t
	
	addi r10, r0, 0x3C
	beq r10,r9,u
	
	addi r10, r0, 0x2A
	beq r10,r9,v
	
	addi r10, r0, 0x1D
	beq r10,r9,w
	
	addi r10, r0, 0x22
	beq r10,r9,x
	
	addi r10, r0, 0x35
	beq r10,r9,y
	
	addi r10, r0, 0x1A
	beq r10,r9,z
	
a:
	addi r12,r0,0x41
	stb r12,0(r11)
	br end

b:
	addi r12,r0,0x42
	stb r12,0(r11)
	br end

c:
	addi r12,r0,0x43
	stb r12,0(r11)
	br end

d:
	addi r12,r0,0x44
	stb r12,0(r11)
	br end

e:
	addi r12,r0,0x45
	stb r12,0(r11)
	br end

f:
	addi r12,r0,0x46
	stb r12,0(r11)
	br end

g:
	addi r12,r0,0x47
	stb r12,0(r11)
	br end

h:
	addi r12,r0,0x48
	stb r12,0(r11)
	br end

i:
	addi r12,r0,0x49
	stb r12,0(r11)
	br end

j:
	addi r12,r0,0x4A
	stb r12,0(r11)
	br end

k:
	addi r12,r0,0x4B
	stb r12,0(r11)
	br end

l:
	addi r12,r0,0x4C
	stb r12,0(r11)
	br end

m:
	addi r12,r0,0x4D
	stb r12,0(r11)
	br end

n:
	addi r12,r0,0x4E
	stb r12,0(r11)
	br end

o:
	addi r12,r0,0x4F
	stb r12,0(r11)
	br end

p:
	addi r12,r0,0x50
	stb r12,0(r11)
	br end

q:
	addi r12,r0,0x51
	stb r12,0(r11)
	br end

r:
	addi r12,r0,0x52
	stb r12,0(r11)
	br end

s:
	addi r12,r0,0x53
	stb r12,0(r11)
	br end

t:
	addi r12,r0,0x54
	stb r12,0(r11)
	br end

u:
	addi r12,r0,0x55
	stb r12,0(r11)
	br end

v:
	addi r12,r0,0x56
	stb r12,0(r11)
	br end

w:
	addi r12,r0,0x57
	stb r12,0(r11)
	br end

x:
	addi r12,r0,0x58
	stb r12,0(r11)
	br end

y:
	addi r12,r0,0x59
	stb r12,0(r11)
	br end

z:
	addi r12,r0,0x5A
	stb r12,0(r11)
	br end

end:
	ldw r9, 0(sp)
	ldw r10, 4(sp)
	ldw r11, 8(sp)
	ldw r12, 12(sp)
	ldw ra, 16(sp)
	addi sp,sp,20

ret