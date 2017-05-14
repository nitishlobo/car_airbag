/*Connections Summary:

Collision
	PC0 -> LED0

Right Indicator
	SW0 -> PB2
	SW1 -> PB0
	PB4 -> LED1

Left Indicator
	SW2 -> PB1
	SW3 -> PB3
	PB5 -> LED2

Car Indicator
	SW4 -> PC4
	PC5 -> LED4

Port Connections to Oscilloscope
	PD0 = TASK 1a
	PD1 = TASK 1b
	PD2 = TASK 2a
	PD3 = TASK 2b Right Indicator
	PD4 = Clock tick
	PD5 = TASK 2b Left Indicator
	PD6 = TASK 2c
*/
.MACRO PUSH_ALL_REGISTERS_MACRO	 //Macro to push all the registers so that the
		push r16				             //interrupts and other tasks do not over-write values
		push r17
		push r18
		push r19
		push r20
		push r21
		push r22
		push r23
		push r24
		push r25
		push r26
		push r27
		push r28
		push r29
		push r30
		push r31
		in r16, SREG
		push r16
.ENDMACRO

.MACRO POP_ALL_REGISTERS_MACRO	//Macro to pop register values back on
		pop r16
		out SREG, r16
		pop r31
		pop r30
		pop r29
		pop r28
		pop r27
		pop r26
		pop r25
		pop r24
		pop r23
		pop r22
		pop r21
		pop r20
		pop r19
		pop r18
		pop r17
		pop r16
.ENDMACRO

.nolist						//Turning on list file generation
.include "m8adef.inc"
.list

.dseg 						//Starting data segment
.org 0x67 				//SRAM address is hex 67

//Reserving bytes in SRAM for variables
clockTickCounterForPW: .byte 1
pulseWidthValue: .byte 1
indicatorFlag: .byte 1
SwitchFlag: .byte 1
toggleLeftFlag: .byte 1
brokenLeftFlag: .byte 1
toggleRightFlag: .byte 1
brokenRightFlag: .byte 1
timerDelayValueRight: .byte 1
timerDelayValueLeft: .byte 1

.cseg
.org $00000					        //Origin address with reset vector as main
		rjmp Main
.org OVF0addr				        //Clock tick address with clockTick vector
		rjmp ClockTick
.org ADCCaddr				        //ADCC interrupt address with collision vector
		rjmp CollisionOfCar

.org   0x0100               //Table address with RPM and load (in RPM/LOAD format)
BaseWidthPulse_Lookup:			//1/1   1/2	1/3    1/4   2/1  2/2   2/3   2/4    3/1  3/2    3/3  3/4   4/1   4/2   4/3   4/4
			.db					0x01, 0x02, 0x03, 0x04, 0x02, 0x04, 0x06, 0x08, 0x03, 0x06, 0x09, 0x0C, 0x04, 0x08, 0x0C, 0x10

.org   0x0080                            //Table address for Factor A
FactorA_Lookup:	                         //A:  0    25     50    75
			.db				0x0C, 0x0B, 0x0A, 0x09   //All values are multiplied by 10 to avoid decimals

.org   0x0180                           //Table address for Factor B
FactorB_Lookup:			                    //B:  1    2     3	   4
			.db				0x04, 0x04, 0x04, 0x03  //All values are multiplied by 4 to avoid decimals

.org $00200					      //Setting address
.include "MECHENG313.inc"	//Including functions from MECHENG313

/********************************************************************************************************************************
 *CODE FOR MAIN BEGINS
 *******************************************************************************************************************************/
Main:
		ldi r16,LOW(RAMEND) 	//Loading lower ram end address in to r16
		out SPL,r16				    //Initialising stack pointer for lower bytes
		ldi r16,HIGH(RAMEND)	//Loading higher ram end address in to r16
		out SPH,r16				    //Initialising stack pointer for higher bytes

	  //Setting up ADC *************
		ldi r16, (1<<MUX0)		//Setting MUX to channel 2. AREF is taken from AVCC
		out ADMUX, r16

		//Switching AD conversion on, enabling interrupts (for collision) and divider rate as 16
		ldi r16, (1<<ADEN) | (1<<ADPS2) | (1<<ADFR) | (1<<ADSC)| (1<<ADIE) | (1<<ADIF)
		out ADCSRA, r16
		cbi DDRC,PC1

	  //Clock counter code *********
		//Initialising clock tick counter for task 1a as 0
		ldi r16, 0
		sts clockTickCounterForPW, r16	   //PW is PulseWidth

		//ClockTick 8-bit Timer/Counter 0
		ldi r16, (1<<CS01) | (1<<CS00)     //Prescaler is loaded as 64.
    out TCCR0, r16						         //Timer Clock = Sys Clock (1MHz) / 16 (prescaler)
		ldi r16, (1<<TOIE0)
		out TIMSK, r16						         //Enabling timer overflow interrupt

		//MaxValue = TOVck (4ms) * Pck (1MHz) / 64 (prescaler) = 62.5
		//TCNT0Value = 255 - MaxValue = 193
		ldi r16, 0xC1
		out TCNT0, r16

	  //Initialisation for collision (Task 2a) ********
		sbi DDRC, PC0

	  //Initialisation for indicator (Task 2b) ********
		//Setting data direction as inputs
		cbi	DDRB, PB0
		cbi DDRB, PB1
		cbi DDRB, PB2
		cbi DDRB, PB3

		//Setting portB 4 and 5 as outputs
		sbi DDRB, PB4
		sbi DDRB, PB5

		//Set LED0 as off  - Right indicator intialised as off
		sbi PORTB, PB4
		//Set LED1 as off  - Left indicator intialised as off
		sbi PORTB, PB5

		//Setting timer delay for blink to 1 sec intially
		ldi r16, 45
		sts timerDelayValueRight, r16
		sts timerDelayValueLeft, r16

		//Initialising right and left indicators to blink normally (not broken)
		ldi r16, $00
		sts toggleRightFlag, r16
		sts toggleLeftFlag, r16

	  //Initialisations for car door indicator (Task 2c) *********
		cbi DDRC, PC4	     //PC4 is input
		sbi PORTC, PC4	   //Setting PC4 to initialy low

		sbi DDRC, PC5	     //PC5 is output
		sbi PORTC,PC5	     //Setting PC5 to initialy low

	  //Enabling interrupts ***********
		sei

    //Main infinite loop ************
forever:
		Start_Task UpTime

		//Checking right indicator
		sbis PINB, PB0
		rcall rightBlink

		//Checking left indicator
		sbis PINB, PB1
		rcall leftBlink

		//Checking car indicator
		rcall carDoorIndicator

		End_Task UpTime
		rjmp forever

/********************************************************************************************************************************
 *MAIN CODE ENDS
 *******************************************************************************************************************************/

//TASK 1a CODE BEGINS
PulseWidthTask:
		//For checking on oscilliscope
		sbi DDRD, PD0
		sbi PORTD, PD0

	  PUSH_ALL_REGISTERS_MACRO

	//LOOKUP OF BASE PULSE WIDTH
		//Loading the RPM (2 MSB of ADCL) into r16
		clr r16
		in r22, ADCL
		bst r22, 7
		bld r16, 1
		bst r22, 6
		bld r16, 0

		//Loading the Load into r17
		clr r17
		bst r22, 5
		bld r17, 1
		bst r22, 4
		bld r17, 0

		//2 MSB of ADCL is the RPM level, next 2 bits are load
		//Formula for BasePulseWidth = ADCL*4 + Load - 1 + 200
		ldi r20, 4
		mul r16, r20   //r0 = ADCL*4
		mov r21, r0
		add r21, r17   //r21 = ADCL*4 + Load

		ldi ZH, $02
		mov ZL, r21
		lpm r21, Z     //r21 = ADCL*4 + Load - 1 + 200
	//END OF LOOKUP OF BASE PULSE WIDTH

	//LOOKUP OF FACTOR A
		//Loading the Factor A into r18
		clr r18
		bst r22, 3
		bld r18, 1
		bst r22, 2
		bld r18, 0

		ldi ZH, $01
		mov ZL, r18
		lpm r18, Z     //r18 = ADCL + 100
	//END OF LOOKUP OF FACTOR A

	//LOOKUP OF FACTOR B
		//Loading the Factor B into r19
		clr r19
		bst r22, 1
		bld r19, 1
		bst r22, 0
		bld r19, 0

		ldi ZH, $03
		mov ZL, r19
		lpm r19, Z
	//END OF LOOKUP OF FACTOR B


	//PULSE WIDTH CALCULATION Pulse Width = ((Base Pulse Width)*(FactorA)*(FactorB))/40 where 40 is used to divide lookup tables
	// (FactorA)*(FactorB)
	clr r1
	clr r0
	mul r18,r19

	// (Base Pulse Width)*(FactorA)*(FactorB)
	mov r22,r0
	mov r23,r1
	mov r20,r21
	clr r21
	rcall mul16x16_16	    //r17:r16 = r23:r22 * r21:r20

	mov r28, r16
	mov r29, r17

	// ((Base Pulse Width)*(FactorA)*(FactorB))/40
	// r27 = truncated PulseWidth
	mov r22, r16
	mov r23, r17
	clr r24
	ldi r19, 40
	clr r20
	clr r21
	rcall div24x24_24	    //r24:r23:r22 = r24:r23:r22 / r21:r20:r19
	mov r27, r22

	//((Base Pulse Width)*(FactorA)*(FactorB))/4
	//r22 = PulseWidth* 10
	mov r22,r28
	mov r23,r29
	clr r24
	ldi r19,4
	clr r20
	clr r21
	rcall div24x24_24	    //r24:r23:r22 = r24:r23:r22 / r21:r20:r19

	//Rounding algorithm
	ldi r21, 10
	mul r27, r21
	mov r19, r0		        //truncated_PulseWidth*10
	sub r22, r19

	ldi r19, 5
	cp r22, r19
	brge rounding
	rjmp finish

rounding:
	inc r27

finish:                //r27 has the final pulsewidth value
	sts pulseWidthValue, r27

	POP_ALL_REGISTERS_MACRO

	cbi PORTD, PD0	     //For checking on oscilliscope
	RET
//TASK 1a CODE ENDS

/*******************************************************************************************************************************/

//TASK 1b CODE STARTS
MonitoringTask:
		//For checking on oscilliscope
		sbi DDRD, PD1
		sbi PORTD, PD1

	//Loading the ADCL into a register
		in r28, ADCL

	//Convert fluid from ounces to Litres
	//Litres = US ounces/ 34
		mov r21,r28
		ldi r22, 34
		rcall div8u		      //r21 = r21/r22 (divide by 34)
		mov r25,r21		      //Store final litres value in r25

		ldi r22, 17		      //Half of 34 to check remainders for rounding
		cp r20, r22		      //Compare remainder to 34
		brge greateq	      //If remainder greater or equal to 17 then branch
		rjmp SKIPgreateq

		greateq:
		inc r25			        //Increment answer for rounding
		SKIPgreateq:

	//Convert from fahrenheit to celsius
	//[�C] = ([�F] - 32) � 5/9
		mov r20,r28
		subi r20, $20	      //Subtract 32 from fahrenheit temperature
		cpi r28, 32
		brlo negative	      //Go to negative if Negative flag is 1
		brpl positive	      //Go to positive if Negative flag is 0

	positive:
		clr r21		          //Clearing registers from previous values
		clr r23
		clr r16
		clr r17
		ldi r22, 5
		rcall mul16x16_16	  //r17:r16 = r23:r22 * r21:r20 (multiply by 5)

		clr r24		          //Clearing registers from previous values
		clr r20
		clr r21
		mov r22,r16
		mov r23,r17
		ldi r19,9
		rcall div24x24_24	  //r24:r23:r22 = r24:r23:r22 / r21:r20:r19 (divide by 9)
		rjmp finishtask		  //Jump to the end of the task

		ldi r19, 5			    //Half of 9 to check remainders for rounding
		cp r16, r19			    //Compare remainder to 5
		brge greateqOne		  //If remainder greater or equal to 5 then branch
		rjmp SKIPgreateqOne

		greateqOne:
		inc r25				      //Increment answer for rounding
		SKIPgreateqOne:

		cln		              //Clear negative flag

	negative:
		clr r21		          //Clearing registers from previous values
		clr r23
		clr r16
		clr r17
		neg r20		          //Replaces R20 with its two�s complement
		ldi r22, 5
		rcall mul16x16_16	  //r17:r16 = r23:r22 * r21:r20 (multiply by 5)

		clr r24		          //Clearing registers from previous values
		clr r20
		clr r21
		mov r22,r16
		mov r23,r17
		ldi r19,9
		rcall div24x24_24   //r24:r23:r22 = r24:r23:r22 / r21:r20:r19 (divide by 9)

		ldi r19, 5			    //Half of 9 to check remainders for rounding
		cp r16, r19			    //Compare remainder to 5
		brge greateqTwo		  //If remainder greater or equal to 5 then branch
		rjmp SKIPgreateqTwo

		greateqTwo:
		inc r25				      //Increment answer for rounding
		SKIPgreateqTwo:

		sen			            //set Negative Flag to 1

	finishtask:		        //Receive jump from the end of the positive calculations
		mov r26,r22		      //Store final celsius value in register r26

		cbi PORTD, PD1      //For checking on oscilliscope
		RET
//TASK 1b CODE ENDS

/*******************************************************************************************************************************/

//TASK 2a CODE STARTS
CollisionOfCar:
		//For checking on oscilliscope
		sbi DDRD, PD2
		sbi PORTD, PD2

		PUSH_ALL_REGISTERS_MACRO

		sbi DDRC, PC0	    //Setting PORTC0 as output port

	//FINDING G VALUE (from ADC inputs)
		ldi r16, 4
		in r23, ADCL	    //Reading ADCL so no corruption of ADCH occurs
		in r23, ADCH	    //Only need to read ADCH and not the ADCL values as ADCL only contributes a max of 3G
		mul r23, r16	    //Shifting ADCH over 2 places to allow for correct G calculation
		mov r23, r0		    //r23 = ADCH in bit pos 2 and 3
	//END OF FINDING G (r23 = input G force)

		//Checking whether input force is equal or above threshold force (r16 = threshold force = 4G)
		cp r23, r16
		brge collisionCase	  //Go to collision subroutine

noCollisionCase:          //If no collision then switch off LED and repeat detectG
		sbi PORTC, PC0	      //LED0 is off
		rjmp finishInterrupt

//If collision occurs switch on LED
collisionCase:
		cbi PORTC, PC0	      //LED0 is on

finishInterrupt:
		POP_ALL_REGISTERS_MACRO

		//For checking on oscilliscope
		cbi PORTD, PD2
		reti
//TASK 2a CODE ENDS

/*******************************************************************************************************************************/

//TASK 2b CODE STARTS
//FOR RIGHT LED
rightBlink:
		//For checking on oscilliscope
		sbi DDRD, PD3
		sbi PORTD, PD3

		PUSH_ALL_REGISTERS_MACRO

		lds r24, timerDelayValueRight

resetRight:
		lds r21, brokenRightFlag		//load r21 with broken flag
		lds r20, toggleRightFlag		//load r20 with toggle flag

		ldi r19, $FF	              //Value of all 1
		ldi r23, $00	              //Value of 0

		sbis PINB, PB2					    //Skip next step if button is pressed
		sts toggleRightFlag, r19		//Set toggle flag to 1
		sbis PINB, PB2
		rjmp finishRightToggle

		cp r20,r19						      //Compare toggle flag and check if it is 1
		brne finishRightToggle			//If it is not 1 skip to the end

		cp r21,r19						      //Check if brokenRightFlag is 1, this means broken state is on
		brne brokenRightOn				  //branch to toggleRightOn

		ldi r24, 45
		sts timerDelayValueRight, r24
		sts brokenRightFlag, r23		//Set broken flag to 0
		sts toggleRightFlag, r23		//Set toggle flag to 0
		rjmp finishRightToggle

brokenRightOn:
		ldi r24, 23
		sts timerDelayValueRight, r24
		sts brokenRightFlag, r19		//Set broken flag to 1
		sts toggleRightFlag, r23		//Set toggle flag to 0

finishRightToggle:
		sbic PINB, PB0
		rjmp finalRight

//On:
		cbi PORTB, PB4	            //LED1 is on
		rcall delay		              //Delay of 1s
		sbis PINB, PB2
		rjmp resetRight

//Off:
		sbi PORTB, PB4	            //LED1 is off
		rcall delay		              //Delay of 1s

		rjmp resetRight

finalRight:
		POP_ALL_REGISTERS_MACRO

		//For checking on oscilliscope
		cbi PORTD, PD3
		ret

/***********************************************************************************************/
//Actual delay of 1s or 0.5s depending on toggle state
delay:
		clr r16		    //Clearing all the registers for use
		clr r17
		ldi r19, 255	//Loading the overflow values for comparison

keepCounting:
		inc r16
		cpse r16, r19
		rjmp keepCounting

//Increasing second register:
		inc r17
		clr r16		    //Resetting count
		cpse r17, r24
		rjmp keepCounting
		ret

//LEFT LED
leftBlink:
		//For checking on oscilliscope
		sbi DDRD, PD5
		sbi PORTD, PD5
		PUSH_ALL_REGISTERS_MACRO

		lds r24, timerDelayValueLeft

resetLeft:
		lds r21, brokenLeftFlag		//load r21 with broken flag
		lds r20, toggleLeftFlag		//load r20 with toggle flag

		ldi r19, $FF	            //Value of all 1
		ldi r23, $00	            //Value of 0

		sbis PINB, PB3				    //Skip next step if button is pressed
		sts toggleLeftFlag, r19		//Set toggle flag to 1
		sbis PINB, PB3
		rjmp finishLeftToggle

		cp r20,r19				        //Compare toggle flag and check if it is 1
		brne finishLeftToggle	    //If it is not 1 skip to the end

		cp r21,r19			          //Check if brokenLeftFlag is 1, this means broken state is on
		brne brokenLeftOn	        //Branch to toggleLeftOn

		ldi r24, 45
		sts brokenLeftFlag, r23	  //Set broken flag to 0
		sts toggleLeftFlag, r23	  //Set toggle flag to 0
		rjmp finishLeftToggle

brokenLeftOn:
		ldi r24, 23
		sts timerDelayValueLeft, r24
		sts brokenLeftFlag, r19	  //Set broken flag to 1
		sts toggleLeftFlag, r23   //Set toggle flag to 0

finishLeftToggle:

		sbic PINB, PB1
		rjmp finalLeft

    //On:
		cbi PORTB, PB5	          //LED2 is on
		rcall delay		            //Delay of 1s
		sbis PINB, PB3
		rjmp resetLeft	          //Checking for broken toggle

//Off:
		sbi PORTB, PB5	          //LED2 is off
		rcall delay		            //Delay of 1s

		rjmp resetLeft

finalLeft:
		POP_ALL_REGISTERS_MACRO

		//For checking on oscilliscope
		cbi PORTD, PD5
		ret
//TASK 2b CODE ENDS

//*******************************************************************************************************************************/

//TASK 2c BEGINS
carDoorIndicator:
		//For checking on oscilliscope
		sbi DDRD, PD6
		sbi PORTD, PD6
		PUSH_ALL_REGISTERS_MACRO
		lds r21, indicatorFlag	     //Load r21 with indicator flag
		lds r20, switchFlag		       //Load r20 with switch flag

		ldi r19, $FF	               //Value of 1
		ldi r23, $00	               //Value of 0

		sbis PINC, PC4			         //Skip next step if button is pressed
		sts switchFlag, r19		       //Set switch flag to 1
		sbis PINC, PC4			         //Skip next step if button is pressed
		rjmp skip				             //Skip to end

		cp r20,r19				           //Compare switch flag and check if it is 1
		brne skip				             //If it is not 1 skip to the end

		cp r21,r19		               //Check if IndicatorFlag is 1, this means led is on
		brne turnOn		               //Branch to turnOn

		// Turn off led
		sbi PORTC, PC5			         // Set Bit in PC5
		sts switchFlag, r23		       //Set switch flag to 0
		sts indicatorFlag, r23	     //Set led indicator to 0
		rjmp skip;

		turnOn:                      //Turn on led
		cbi PORTC, PC5			         //Clear Bit in PC5
		sts switchFlag, r23		       //Set switch flag to 0
		sts indicatorFlag,r19	       //Set led indicator to 1
		rjmp skip

skip:
		POP_ALL_REGISTERS_MACRO

		//For checking on oscilliscope
		cbi PORTD, PD6
		RET
//TASK 2c ENDS

/*******************************************************************************************************************************/
//CLOCK TICK CODE BEGINS
ClockTick:
		Start_Task 	ClockTick_Task	//For checking on oscilliscope
		PUSH_ALL_REGISTERS_MACRO

		//Enabling interrupts for collision detection
		sei

		//MaxValue = TOVck (4ms) * Pck (1MHz) / 64 (prescaler) = 62.5
		//TCNT0Value = 255 - MaxValue = 193
		ldi r16, 0xC1
		out TCNT0, r16

		//Incrementing counter for pulse width
		lds r16, clockTickCounterForPW
		inc r16
		sts clockTickCounterForPW, r16

		//Comparing pulse width value to the clock tick and calling pulseWidth if equal
		lds r17, pulseWidthValue
		cp r16, r17
		brge calculatePW
		rjmp dontCalculatePW

calculatePW:
		rcall PulseWidthTask
		//Resetting counter to 0
		ldi r16, 0
		sts clockTickCounterForPW, r16

dontCalculatePW:
		rcall MonitoringTask

		POP_ALL_REGISTERS_MACRO
		End_Task	ClockTick_Task	//For checking on oscilliscope
		RETI	                    //Returning from clock interrupt

//CLOCK TICK CODE ENDS
/*******************************************************************************************************************************/
