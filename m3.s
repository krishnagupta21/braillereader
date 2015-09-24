#.include "nios_macros.s"
.equ ADDR_VGA, 0x08000000
.equ ADDR_CHAR, 0x09000000
.equ ADDR_SLIDESWITCHES, 0x10000040
.equ ADDR_REDLEDS, 0x10000000
.equ ADDR_GREENLEDS, 0x10000010	/* 9 bits corresponding to 9 LEDGs starting at this address */
.equ ADDR_PUSHBUTTONS, 0x10000050
.equ ADDR_JP1_IRQ, 0x800      /* IRQ line for GPIO JP1 (IRQ11) */
.equ ADDR_JP1_EDGE, 0x1000006C      /* address Edge Capture register GPIO JP2 */

.data
.equ TIMER0_BASE, 0x10002000
.equ  TIMER0_STATUS,    0
.equ  TIMER0_CONTROL,   4
.equ  TIMER0_PERIODL,   8
.equ  TIMER0_PERIODH,   12
.equ  TIMER0_SNAPL,     16
.equ  TIMER0_SNAPH,     20
.equ  TICKSPERSEC,      300
.equ  STOP_TICKSPERSEC,  1
.equ ADDR_JP1, 0x10000060  /* address GPIO JP1*/
.equ ADDR_REDLEDS, 0x10000000
.equ  TICKSperTICKSPERSEC, 5
.equ  curr_TICKSperTICKSPERSEC, 0
.equ  stop_TICKSperTICKSPERSEC, 0
#.equ   total_TICKSperTICKSPERSEC, 120000		# 2.5 seconds
.equ   total_TICKSperTICKSPERSEC, 33750		# 2.5 seconds
.equ   init_location, 0x090004AA

starting_text:
	.byte 'S','a','g','n','i','k',' ','a','n','d',' ','K','r','i','s','h','n','a','','s','B','r','a','i','l','l','e',' ','E','n','c','o','d','e','r','/','D','e','c','o','d','e','r'

prompt_text:
	.byte 'P','l','e','a','s','e',' ','E','n','t','e','r',' ','6',' ','C','h','a','r','a','c','t','e','r','s',' ','o','n',' ','t','h','e',' ','P','s','2',' ','K','e','y','b','o','a','r','d'
	
key_text:
	.byte 'P','r','e','s','s',' ','K','E','Y','[','1',']',' ','t','o',' ','m','o','v','e',' ','t','h','e',' ','M','o','t','o','r'
	
tickspersec_counter:
	.word 0															# counts how many seconds have passed that the motor's been on.

colour_array:
	.word 33,14,47,4,63,30		/* random set of numbers to draw boxes */
	
sensor_input:
	.word 0
	
character_location:
	.word 0x0900072A
	
sensor_text:
	.byte 'S','E','N','S','O','R',' ','R','E','A','D',' ','V','A','L','U','E','S',':'
	
draw_bool:
	.word 0
	
flag:
	.word 0
	
.section .exceptions, "ax"
 _interrupt1:
 subi sp, sp, 36
 stw et, 0(sp)
 stw et, 4(sp)
 stw ea, 8(sp)
 stw r4, 12(sp)
 stw r5, 16(sp)
 stw r8, 20(sp)
 stw r9, 24(sp)
 stw r10, 28(sp)
 stw r22, 32(sp)
 
	 rdctl et, ctl4                    /* check the interrupt pending register (ctl4) */
	 movia r2, ADDR_JP1_IRQ    
	 and	r2, r2, et                  /* check if the pending interrupt is from GPIO JP1 */
	 beq   r2, r0, check_timer   

	 movia r2, ADDR_JP1_EDGE           /* check edge capture register from GPIO JP1 */
	 ldwio et, 0(r2)
	 andi	r2, et, 0x08000000         /* mask bit 27 (sensor 0) */ 
	 bne r2, r0, do_color_sensor_stuff 
	  
	check_timer:
	 rdctl et, ipending  #check ipending(ctl4)
	 andi et, et, 0x1    #if(irq0 !=1)
	 bne et, r0, do_timer_stuff
	 br return_intr
 
do_color_sensor_stuff:
	movia r5, ADDR_GREENLEDS
	movia  r8, 0xffffffff
	stwio r8, 0(r5)
	
	movia r9,flag
	ldw r5,0(r9)
	beq r5,r0,increase
	br quit
	
	increase:
	addi r5,r0,1
	stw r5,0(r9)
	movia r5, sensor_input
	ldw r10, 0(r5)
	addi r10, r10, 1
	stw r10, 0(r5)
	
		#addi r8, r0, 2500
		#addi r5, r0, 0
	poll_until_white:
		#addi r5, r5, 1
		#blt r5, r8, poll_until_white
	
		movia r4, ADDR_JP1
		ldwio r5, 0(r4)
		srli r5,r5,27
		andi r5,r5,0x1 /* if its 1 then it means its black */
		addi r8,r0,1
		bne r5,r8,poll_until_white
	
	quit:
	movia r5, ADDR_JP1_EDGE  
	stwio r0, 0(r5)	
    br return_intr
	
do_timer_stuff:
	movia  r8, 0xffdfffff      /* disable all motors and sensors*/
	stwio  r8, 0(r4)
	stwio r0, (et)

continue_timer:
	call waitasec
poll_start_motor:
	movia r8, TIMER0_BASE
	ldwio       r9, TIMER0_STATUS(r8)   # check if the TO bit of the status register is 1
    andi        r9, r9, 0x1
    beq         r9, r0, poll_start_motor
	movi        r9, 0x0             	# clear the TO bit
    stwio       r9, TIMER0_STATUS(r8)
	movia r8, TIMER0_BASE
	movui r9,%lo(TICKSPERSEC)
	stwio r9,TIMER0_PERIODL(r8)
 	movui r9,%hi(TICKSPERSEC)
	stwio r9,TIMER0_PERIODH(r8)
	
	stwio r0,TIMER0_STATUS(r8) 		#reset timer
	movui r9, 0b101 				#enable start and interrupt and disable cont
	stwio r9,TIMER0_CONTROL(r8)
	
	movia r10, tickspersec_counter
	ldw r9, 0(r10)							#get how many times the motor's run so far
	movia r10, total_TICKSperTICKSPERSEC 	#get how many times the motor should run
	bgt r9, r10, stop_motor

start_motor_again:
	addi r9, r9, 1							#increment how long the motor's been on for.
	movia r10, tickspersec_counter
	stw r9, 0(r10)
	
	movia  r4, ADDR_JP1
	movia  r5, 0xffdffffC      /* motor0 enabled (bit0=0), direction set to forward (bit1=0) */
	stwio  r5, 0(r4)
	
	movia  r8, 0xffffffff
	movia r22, ADDR_REDLEDS
	stwio r8, 0(r22)
	br return_intr

start_motor_init:
	call draw_written_char				#this function draws the character on the VGA
	addi r9, r0, 0
	movia r10, tickspersec_counter
	stw r9, 0(r10)						#restore the values of how long the motor's run for and...
	stw r9, 4(r10)						# ... how long it's been stopped for.
	
	movia r9, sensor_input
    stw r0, 0(r9)
	
	br start_motor_again
	
stop_motor:
	#movia r10, tickspersec_counter
	#ldw r9, 4(r10)							#get how many times the motor's been stopped so far
	#movia r10, total_TICKSperTICKSPERSEC 	#get how many times the motor should be stopped for
	#bgt r9, r10, start_motor_init
	#addi r9, r9, 1
	#movia r10, tickspersec_counter
	#stw r9, 4(r10)							#increment how long the motor's been stopped for.
	
	/* turn off all the LEDS */
	movia r22, ADDR_REDLEDS
	movia r8, 0x00000000
	stwio r8, 0(r22)
	
	movia r10, ADDR_PUSHBUTTONS
	ldwio r9, (r10)
	andi r9, r9, 0x2
	bne r9, r0, start_motor_init			#if KEY[1] is pressed, then start the motor again.

return_intr: 
	 ldw et, 0(sp)
	 ldw et, 4(sp)
	 ldw ea, 8(sp)
	 ldw r4, 12(sp)
	 ldw r5, 16(sp)
	 ldw r8, 20(sp)
	 ldw r9, 24(sp)
	 ldw r10, 28(sp)
	 ldw r22, 32(sp)
	 addi sp, sp, 36
	 subi ea,ea,4
	 eret
 
/*********************************************************************
 
	GLOBAL VARIABLES:
		r6 = stores the maximum X pixel on the VGA
		r7 = stores the maximum Y pixel on the VGA
		r8 = stores the maximum X character pixel
		r9 = stores the maximum Y character pixel
		
***********************************************************************/
 
.text
.global _start
/************************ START of main *******************************/
_start:
	/******************* START of VGA code ****************************/
	movia r1, colour_array
	movia r2, ADDR_VGA
	movia r3, ADDR_CHAR
	
	movia sp, 0x800000
	addi r6, r0, 320			/* r6 stores the max X pixel */
	addi r7, r0, 239			/* r7 stores the max Y pixel */
	addi r8, r0, 79				/* r8 stores the max X character pixel */
	addi r9, r0, 59				/* r9 stores the max Y character pixel */
	addi r14, r0, 0
	addi r15, r0, 6
  
	addi r3, r3, 3				/* Initialize the location of the first character. */
	addi r3, r3, 1152
	call clear_screen
	call starting_drawscreen	
	call read_ps2				# call to the function to read from the ps2, and store the information in an array
	call clear_screen
	call draw_init
	call draw_motor_prompt
	call draw_shapes
	/******************* END of VGA code ******************************/
	/****************** START of MOTOR code ***************************/
start_motor:	
	movia sp, 0x800000
	
	/* Start the timer and motor only when KEY[1] is pressed. */
	movia r10, ADDR_PUSHBUTTONS
	ldwio r9, (r10)
	andi r9, r9, 0x2
	beq r9, r0, start_motor			#if KEY[1] is pressed, then start the motor again.
	
	movia r10, ADDR_PUSHBUTTONS
	ldwio r11, (r10)
	andi r11, r11, 0x4
	bne r11, r0, start_motor			#if KEY[1] is pressed, then start the motor again.
	
 	movia r10, TIMER0_BASE
	movui r11,%lo(TICKSPERSEC)
	stwio r11,TIMER0_PERIODL(r10)
 	movui r11,%hi(TICKSPERSEC)
	stwio r11,TIMER0_PERIODH(r10)
	stwio r0,TIMER0_STATUS(r10) 		#reset timer
	movui r11, 0b101 				#enable start and interrupt and disable cont
	stwio r11,TIMER0_CONTROL(r10)
	
	movia  r8, ADDR_JP1         /* load address GPIO JP1 into r8*/
   movia r9,0xffffffff
   stwio r9,0(r8)
	
	movia  r4, ADDR_JP1
	movia  r5, 0x07f557ff      	/* disable all motors and sensors*/
	stwio  r5, 4(r4)
	
	/* load sensor0 threshold value HEX 5 and enable sensor0*/
 
   movia  r5,  0xFA3FFBFC      /* set motors off enable threshold load sensor 3*/
   stwio  r5,  0(r4)            /* store value into threshold register

/* disable threshold register and enable state mode*/
  
   movia  r5,  0xffdffffC
   stwio  r5,  0(r4)
   
   movia  r5, 0x8000000        /* enable interrupts on sensor 0`*/
   stwio  r5, 8(r4)
   
start_counter:

	movia  r13,  0b0100000000001   /* enable interrupt for GPIO JP1 (IRQ11) and timer (irq0) */
    wrctl  ctl3, r13

    movia  r13, 1
    wrctl  ctl0, r13 
	
	movia r5, ADDR_GREENLEDS
	movia  r8, 0x0
	stwio r8, 0(r5)
	
inf_poll:
	ldwio r5, 0(r4)
	srli r5,r5,27
	andi r5,r5,0x1
	addi r8,r0,1
	beq r5,r8,set_bool

	br start_counter	
	
set_bool:
	movia r9,flag
	stw r0,0(r9)
	br start_counter
	
	/******************* END of MOTOR code ******************************/
	
/* Function called by the interrupt that starts the timer, and is used to determine how long 
   the motor has to be turned OFF for. */
waitasec:
	addi sp, sp, -12
	stw r8, 0(sp)
	stw r9, 4(sp)
	stw ra, 8(sp)

	movi r9,0b0
	wrctl ienable,r9
	movi r9,0b0
	wrctl status,r9
	movia r8, TIMER0_BASE
	movui r9,%lo(STOP_TICKSPERSEC)
	stwio r9,TIMER0_PERIODL(r8)
 	movui r9,%hi(STOP_TICKSPERSEC)
	stwio r9,TIMER0_PERIODH(r8)
	stwio r0,TIMER0_STATUS(r8) #reset timer 
	movui r9, 0b100 #enable start and interrupt and disable cont
	stwio r9,TIMER0_CONTROL(r8)
	ldw r8, 0(sp)
	ldw r9, 4(sp)
	ldw ra, 8(sp)
	addi sp, sp, 12	
ret
/************************* END of main **************************************/

/******************* Start of all the minor functions ***********************/
/************************ CLEAR SCREEN FUNCTION *****************************/
/* function that draws clears the screen, so more characters can be written */
clear_screen:
	addi sp, sp, -24
	stw r4, 0(sp)
	stw r10, 4(sp)
	stw r11, 8(sp)
	stw r12, 12(sp)
	stw r13, 16(sp)
	stw ra, 20(sp)
	
	movia r2, ADDR_VGA
	mov r4, r2						/* r4 is the register holding the pixel location */
	addi r11, r0, 0					/* stores the y-value */
	addi r13, r0, 0					/* stores the previous value of r4 */

	set_screen_black:
		addi r10, r0, 0				/* stores the x-value */
		mov r13, r4					/* saves the old value of r4 */
		bgt r11, r7, return_screen	/* reached the r7 means we're done setting the screen white */
	
	set_black:
		movui r12, 0x0000 			/* r12 now stores a black pixel */
		sthio r12, 0(r4)
		addi r4, r4, 2				/* increment to the next pixel in the X direction*/
		addi r10, r10, 1
		blt r10, r6, set_black
	
		mov r4, r13					/* restore the old value of r4, and then... */
		addi r4, r4, 1024			/* ... increment to the next pixel in the Y direction */
		addi r11, r11, 1			/* increment the location in the y-direction */
		br set_screen_black
		
	return_screen:
		ldw r4, 0(sp)
		ldw r10, 4(sp)
		ldw r11, 8(sp)
		ldw r12, 12(sp)
		ldw r13, 16(sp)
		ldw ra, 20(sp)
		addi sp, sp, 24
ret

/************************ STARTING SCREEN FUNCTION *************************/
starting_drawscreen:
	addi sp, sp, -76
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
	stw r25, 68(sp)
	stw ra, 72(sp)	
	
	movia r10, starting_text
	movia r11, ADDR_CHAR
	addi r11, r11, 131
	addi r12, r0, 0
	addi r13, r0, 19
	
draw_text_start:
	bgt r12, r13, draw_next_text
	addi r12, r12, 1
	ldb r14, 0(r10)
	stbio r14, 0(r11)
	addi r11, r11, 1
	addi r10, r10, 1
	br draw_text_start
	
draw_next_text:
	addi r13, r0, 22
	addi r12, r0, 0
	movia r11, ADDR_CHAR
	addi r11, r11, 259
	
	draw_set:
	bgt r12, r13, draw_prompt_text
	addi r12, r12, 1
	ldb r14, 0(r10)
	stbio r14, 0(r11)
	addi r11, r11, 1
	addi r10, r10, 1
	br draw_set
	
draw_prompt_text:
	movia r10, prompt_text
	addi r13, r0, 44
	addi r12, r0, 0
	movia r11, ADDR_CHAR
	addi r11, r11, 515
	
	draw_prompt_set:
	bgt r12, r13, return_to_main
	addi r12, r12, 1
	ldb r14, 0(r10)
	stbio r14, 0(r11)
	addi r11, r11, 1
	addi r10, r10, 1
	br draw_prompt_set
	
return_to_main:
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
	ldw r25, 68(sp)
	ldw ra, 72(sp)
	addi sp, sp, 76
	ret

draw_motor_prompt:	
		addi sp, sp, -76
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
	stw r25, 68(sp)
	stw ra, 72(sp)	
	
	movia r10, key_text
	movia r11, ADDR_CHAR
	addi r11, r11, 131
	addi r11, r11, 5120
	addi r12, r0, 0
	addi r13, r0, 29
	
draw_key_prompt:
	bgt r12, r13, return_from_drawkey
	addi r12, r12, 1
	ldb r14, 0(r10)
	stbio r14, 0(r11)
	addi r11, r11, 1
	addi r10, r10, 1
	br draw_key_prompt
	
return_from_drawkey:
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
	ldw r25, 68(sp)
	ldw ra, 72(sp)
	addi sp, sp, 76
ret
/************************ DRAW SHAPES FUNCTION *****************************/
/* function to draw the Braille on the VGA */
draw_shapes:
	addi sp, sp, -76
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
	stw r25, 68(sp)
	stw ra, 72(sp)
	
	mov r4, r2
	addi r4, r4, 30728		#set the icon at some location defined by 30728
	addi r14, r0, 0			# stores how many boxes have been drawn
	addi r15, r0, 6			# stores how many boxes will be drawn per character
	addi r16, r0, 0			# stores the top left coordinate of a box
	addi r17, r0, 0			# stores the location of the pixel before the last pixel
	addi r19, r0, 15 		# stores how far down the box has to go
	addi r20, r0, 6			# stores how many character sets we're going to draw
	addi r21, r0, 0			# stores how many characters sets have been drawn
	addi r11, r4, 15624		# stores the length of the box
	mov r22, r4				# stores the location of the first set's first box.
	movia r5, CHARACTERS
	/* Here, determine whether the first box is full or empty,
	   and go to "draw_next_box_full" or "draw_next_box_empty" respectively. */
		ldw r23, 0(r1)					/* gets the value pointed to by r1 */
		andi r24, r23, 0x1
		srli r23, r23, 1
		bne r24, r0, draw_next_box_full	/* if r23 is 4, draw a full box. Otherwise, draw an empty box */
	
	draw_next_box_empty:		
		/*************** Draw the boxes ************************/
		addi r18, r0, 0		# stores where in the y axes we are
		addi r4, r4, 35		# increment the X location of start.
		mov r16, r4

	initialization_X_empty:
		addi r10, r4, 24
		addi r17, r4, 22
		mov r12, r4					/* stores the old value of r4 */
	
	draw_box_X_empty:		
		/* For an empty square, we're going to have to check to see if... */
		/*... we're at the first pixel, or last pixel. */
		beq r4, r12, store_colour		/* Checks if we're at the first column */
		beq r4, r17, store_colour		/* Checks if we're at the last column */
		beq r18, r0, store_colour		/* Checks if we're at the first row */
		beq r18, r19, store_colour		/* Checks if we're at the last row */
		movui r13, 0x0000				/* If not at the location of a white pixel, then draw a black pixel */
		sthio r13, 0(r4)
		br continue_empty
		
		store_colour:
			movui r13, 0xffff  			/* White pixel */
			sthio r13, 0(r4)
		
		continue_empty:
			addi r4, r4, 2 					/* increment along the X axis */
			blt r4, r10, draw_box_X_empty
			mov r4, r12						/* restore the old value of r4, then ... */
			addi r18, r18, 1
			addi r4, r4, 1024				/* ... increment Y axis component */
			blt r4, r11, initialization_X_empty
			addi r14, r14, 1				/* increment how many boxes have been drawn */
			mov r4, r16
			/* Again, determine whether the next box is full or empty, 
		       and then go to "draw_next_box_full" or "draw_next_box_empty" respectively. */
			blt r14, r15, determine_next_box	/* if 6 boxes haven't been drawn yet, keep going.*/
			addi r18, r0, 0
			addi r14, r0, 0
			addi r21, r21, 1			/* determines how many sets have been drawn */
			
			/************** Draw the character first. **************/
			ldbio r6, 0(r5)
			stbio r6, 0(r3) 		/* character (3,9) is x + y*128 so (3 + 1152 = 1155) */
			addi r3, r3, 640		/* Increment the location of the next characters. */
			addi r5, r5, 1
			addi r6, r0, 319			/* r6 stores the max X pixel */
			
			/************** Draw the next set of boxes *************/
			blt r21, r20, draw_next_set
			br return_shapes
	
	draw_next_box_full:
		addi r4, r4, 35		# increment the X location of start.
		mov r16, r4

	initialization_X_full:
		addi r10, r4, 24
		mov r12, r4					/* stores the old value of r4 */
		movui r13, 0xffff  			/* White pixel */
		sthio r13, 0(r4)
	
	draw_box_X_full:
		movui r13, 0xffff  			/* White pixel */
		sthio r13, 0(r4)
		addi r4, r4, 2 				/* increment along the X axis */
		blt r4, r10, draw_box_X_full
		mov r4, r12					/* restore the old value of r4, then ... */
		addi r4, r4, 1024			/* ... increment Y axis component */
		blt r4, r11, initialization_X_full
		addi r14, r14, 1			/* increment how many boxes have been drawn */
		mov r4, r16
		/* Again, determine whether the next box is full or empty, 
		   and then go to "draw_next_box_full" or "draw_next_box_empty" respectively. */
		blt r14, r15, determine_next_box	/* if 6 boxes haven't been drawn yet, keep going. */
		addi r18, r0, 0
		addi r14, r0, 0
		addi r21, r21, 1			/* determines how many sets have been drawn */
			
		/************** Draw the character first. **************/
		ldbio r6, 0(r5)
		stbio r6, 0(r3) 		/* character (3,9) is x + y*128 so (3 + 1152 = 1155) */
		addi r3, r3, 640		/* Increment the location of the next characters. */
		addi r5, r5, 1
		addi r6, r0, 319			/* r6 stores the max X pixel */
			
		/************** Draw the next set of boxes *************/
		blt r21, r20, draw_next_set
		br return_shapes
		
	determine_next_box:
		andi r24, r23, 0x1
		srli r23, r23, 1
		bne r24, r0, draw_next_box_full	/* if r23 is 4, draw a full box. Otherwise, draw an empty box */
		br draw_next_box_empty
	
	/* Used to draw the next row of squares */
	draw_next_set:
		mov r4, r22
		addi r4, r4, 20480	# add 20480 to the last value of r4
		mov r22, r4
		addi r11, r4, 15624	# stores the length of the box
		addi r1, r1, 4
		ldw r23, 0(r1)
		/* Again, determine whether the next box is full or empty, 
		   and then go to "draw_next_box_full" or "draw_next_box_empty" respectively. */
		br determine_next_box
	
	return_shapes:
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
		ldw r25, 68(sp)
		ldw ra, 72(sp)
		addi sp, sp, 76
		ret

/* This functions finds determines which character was input, and draws the character on the VGA.	*/
draw_written_char:
	addi sp, sp, -32
	stw r4, 0(sp)
	stw r5, 4(sp)
	stw r6, 8(sp)
	stw r7, 12(sp)
	stw r8, 16(sp)
	stw r2, 20(sp)
	stw r3, 24(sp)
	stw ra, 28(sp)
	
	movia r5, sensor_input	#send the sensor values into the "return_char" function
	ldw r4, 0(r5)
	call return_char		#at the end of this call, r2 will hold the value of the location of the character in the CHARACTER array
	addi r6, r0, 1			#r6 will be used to hold where in the CHARACTER array we are.
	movia r7, CHARACTERS
	
	movia r4, character_location
	ldw r3, 0(r4)
	
	find_location:
		beq r6, r2, draw_char
		addi r6, r6, 1		#increment the location in the CHARACTER array.
		addi r7, r7, 1		#increment the address of the CHARACTER array.
		br find_location
	
	draw_char:
		ldb r6, 0(r7)		#retrieve the character.
		stb r6, 0(r3)
		addi r3, r3, 2
		stw r3, 0(r4)
		
	
	ldw r4, 0(sp)
	ldw r5, 4(sp)
	ldw r6, 8(sp)
	ldw r7, 12(sp)
	ldw r8, 16(sp)
	ldw r2, 20(sp)
	ldw r3, 24(sp)
	ldw ra, 28(sp)
	addi sp, sp, 32
ret

draw_init:
	addi sp, sp, -32
	stw r4, 0(sp)
	stw r5, 4(sp)
	stw r6, 8(sp)
	stw r7, 12(sp)
	stw r8, 16(sp)
	stw r2, 20(sp)
	stw r3, 24(sp)
	stw ra, 28(sp)
	
	movia r3, init_location
	movia r4, sensor_text
	addi r5, r0, 19
	addi r6, r0, 0
	
	draw_character_draw_init:
		bgt r6, r5, continue_draw_init
		ldb r7, 0(r4)
		stbio r7, 0(r3)
		addi r4, r4, 1
		addi r3, r3, 1
		addi r6, r6, 1
		br draw_character_draw_init
		
	continue_draw_init:
	ldw r4, 0(sp)
	ldw r5, 4(sp)
	ldw r6, 8(sp)
	ldw r7, 12(sp)
	ldw r8, 16(sp)
	ldw r2, 20(sp)
	ldw r3, 24(sp)
	ldw ra, 28(sp)
	addi sp, sp, 32
ret

draw_white_screen_test:
addi sp, sp, -24
	stw r4, 0(sp)
	stw r10, 4(sp)
	stw r11, 8(sp)
	stw r12, 12(sp)
	stw r13, 16(sp)
	stw ra, 20(sp)
	
	movia r2, ADDR_VGA
	mov r4, r2						/* r4 is the register holding the pixel location */
	addi r11, r0, 0					/* stores the y-value */
	addi r13, r0, 0					/* stores the previous value of r4 */

	set_screen_black1:
		addi r10, r0, 0				/* stores the x-value */
		mov r13, r4					/* saves the old value of r4 */
		bgt r11, r7, return_screen1	/* reached the r7 means we're done setting the screen white */
	
	set_black1:
		movui r12, 0xFFFF 			/* r12 now stores a black pixel */
		sthio r12, 0(r4)
		addi r4, r4, 2				/* increment to the next pixel in the X direction*/
		addi r10, r10, 1
		blt r10, r6, set_black1
	
		mov r4, r13					/* restore the old value of r4, and then... */
		addi r4, r4, 1024			/* ... increment to the next pixel in the Y direction */
		addi r11, r11, 1			/* increment the location in the y-direction */
		br set_screen_black1
		
	return_screen1:
		ldw r4, 0(sp)
		ldw r10, 4(sp)
		ldw r11, 8(sp)
		ldw r12, 12(sp)
		ldw r13, 16(sp)
		ldw ra, 20(sp)
		addi sp, sp, 24
ret