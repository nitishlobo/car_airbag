; Description  - 16 bit multiplication routines
; Target       - ATmega8/8a
;
; This application note shows a number of examples of how to implement
; 16 bit multiplication using a hardware multiplier.
; Refer to each function header for details.
; Functions included in this file are:
;
; mul16x16_16    - Multiplication of two 16 bit numbers with a 16 bit result.
; mul16x16_32    - Unsigned multiplication of two 16 bit numbers with a 32 bit result.
; muls16x16_32   - Signed multiplication of two 16 bit numbers with a 32 bit result.
; mac16x16_32    - Signed cumulative multiplication of two 16 bit numbers with a 32 bit result.
; fmuls16x16_32  - Signed fraction multiplication of two 16 bit numbers with a 32 bit result.
; fmac16x16_32   - Signed fraction cumulative multiplication of two 16 bit numbers with a 32 bit result.


;******************************************************************************
; FUNCTION      - mul16x16_16
; DESCRIPTION   - Multiply two 16 bit numbers with a 16 bit result.
; USAGE         - r17:r16 = r23:r22 * r21:r20
; STATISTICS
;                 Cycles - 9 + ret
;                 Words - 6 + ret
;                 Register usage - r0, r1 and r16 to r23 (8 registers)
; NOTES
;	Any register pair can be used as long as the result and the two operands do not share register pairs.
;	The routine is non-destructive to the operands.

mul16x16_16:
	mul	r22, r20		; al * bl
	movw	r17:r16, r1:r0
	mul	r23, r20		; ah * bl
	add	r17, r0
	mul	r21, r22		; bh * al
	add	r17, r0
	ret


;******************************************************************************
; FUNCTION     - mul16x16_32
; DESCRIPTION  - Unsigned multiplication of two 16 bit numbers with a 32 bit result.
; USAGE        - r19:r18:r17:r16 = r23:r22 * r21:r20
; STATISTICS
;                Cycles -	17 + ret
;                Words - 13 + ret
;                Register usage - r0 to r2 and r16 to r23 (11 registers)
; NOTE
; Any register pair can be used as long as the 32 bit result and the two
; operands does not share register pairs. The routine is non-destructive to the operands.

mul16x16_32:
	clr	r2
	mul	r23, r21		; ah * bh
	movw	r19:r18, r1:r0
	mul	r22, r20		; al * bl
	movw	r17:r16, r1:r0
	mul	r23, r20		; ah * bl
	add	r17, r0
	adc	r18, r1
	adc	r19, r2
	mul	r21, r22		; bh * al
	add	r17, r0
	adc	r18, r1
	adc	r19, r2
	ret


;******************************************************************************
; FUNCTION    - muls16x16_32
; DESCRIPTION - Signed multiplication of two 16 bit numbers with a 32 bit result.
; USAGE       - r19:r18:r17:r16 = r23:r22 * r21:r20
; STATISTICS
;               Cycles - 19 + ret
;               Words -	15 + ret
;               Register usage - r0 to r2 and r16 to r23 (11 registers)
; NOTE
;	The routine is non-destructive to the operands.

muls16x16_32:
	clr	r2
	muls	r23, r21		; (signed)ah * (signed)bh
	movw	r19:r18, r1:r0
	mul	r22, r20		; al * bl
	movw	r17:r16, r1:r0
	mulsu	r23, r20		; (signed)ah * bl
	sbc	r19, r2
	add	r17, r0
	adc	r18, r1
	adc	r19, r2
	mulsu	r21, r22		; (signed)bh * al
	sbc	r19, r2
	add	r17, r0
	adc	r18, r1
	adc	r19, r2
	ret


;******************************************************************************
; FUNCTION     - mac16x16_32
; DESCRIPTION  - Signed multiply accumulate of two 16 bit numbers with a 32 bit result.
; USAGE        - r19:r18:r17:r16 += r23:r22 * r21:r20
; STATISTICS
;	               Cycles -	23 + ret
;	               Words - 19 + ret
;	               Register usage - r0 to r2 and r16 to r23 (11 registers)

mac16x16_32:
	clr	r2

	muls	r23, r21		; (signed)ah * (signed)bh
	add	r18, r0
	adc	r19, r1

	mul	r22, r20		  ; al * bl
	add	r16, r0
	adc	r17, r1
	adc	r18, r2
	adc	r19, r2

	mulsu	r23, r20		; (signed)ah * bl
	sbc	r19, r2
	add	r17, r0
	adc	r18, r1
	adc	r19, r2

	mulsu	r21, r22		; (signed)bh * al
	sbc	r19, r2
	add	r17, r0
	adc	r18, r1
	adc	r19, r2

	ret

mac16x16_32_method_B:     ; uses two temporary registers
                          ; (r4,r5), but reduces cycles/words
                          ; by 1
	clr	r2

	muls	r23, r21		; (signed)ah * (signed)bh
	movw	r5:r4,r1:r0

	mul	r22, r20      ; al * bl

	add	r16, r0
	adc	r17, r1
	adc	r18, r4
	adc	r19, r5

	mulsu	r23, r20		; (signed)ah * bl
	sbc	r19, r2
	add	r17, r0
	adc	r18, r1
	adc	r19, r2

	mulsu	r21, r22		; (signed)bh * al
	sbc	r19, r2
	add	r17, r0
	adc	r18, r1
	adc	r19, r2

	ret


;******************************************************************************
; FUNCTION    - fmuls16x16_32
; DESCRIPTION - Signed fractional multiplication of two 16 bit numbers with a 32 bit result.
; USAGE       - r19:r18:r17:r16 = ( r23:r22 * r21:r20 ) << 1
; STATISTICS
;	              Cycles - 20 + ret
;	              Words - 16 + ret
;	              Register usage - r0 to r2 and r16 to r23 (11 registers)
; NOTE
;	The routine is non-destructive to the operands.

fmuls16x16_32:
	clr	r2
	fmuls	r23, r21		  ; ( (signed)ah * (signed)bh ) << 1
	movw	r19:r18, r1:r0
	fmul	r22, r20		  ; ( al * bl ) << 1
	adc	r18, r2
	movw	r17:r16, r1:r0
	fmulsu	r23, r20		; ( (signed)ah * bl ) << 1
	sbc	r19, r2
	add	r17, r0
	adc	r18, r1
	adc	r19, r2
	fmulsu	r21, r22		; ( (signed)bh * al ) << 1
	sbc	r19, r2
	add	r17, r0
	adc	r18, r1
	adc	r19, r2
	ret


;******************************************************************************
; FUNCTION    - fmac16x16_32
; DESCRIPTION - Signed fractional cumulative multiplication of two 16 bit numbers with
;	              a 32 bit result.
; USAGE       - r19:r18:r17:r16 += (r23:r22 * r21:r20) << 1
; STATISTICS
;	              Cycles - 25 + ret
;	              Words - 21 + ret
;	              Register usage - r0 to r2 and r16 to r23 (11 registers)

fmac16x16_32:
	clr	r2

	fmuls	r23, r21		; ( (signed)ah * (signed)bh ) << 1
	add	r18, r0
	adc	r19, r1

	fmul	r22, r20		; ( al * bl ) << 1
	adc	r18, r2
	adc	r19, r2
	add	r16, r0
	adc	r17, r1
	adc	r18, r2
	adc	r19, r2

	fmulsu	r23, r20	; ( (signed)ah * bl ) << 1
	sbc	r19, r2
	add	r17, r0
	adc	r18, r1
	adc	r19, r2

	fmulsu	r21, r22	; ( (signed)bh * al ) << 1
	sbc	r19, r2
	add	r17, r0
	adc	r18, r1
	adc	r19, r2

	ret

fmac16x16_32_method_B:			; uses two temporary registers
					                  ; (r4,r5), but reduces cycles/words
					                  ; by 2
	clr	r2

	fmuls	r23, r21       ; ( (signed)ah * (signed)bh ) << 1
	movw	r5:r4,r1:r0
	fmul	r22, r20       ; ( al * bl ) << 1
	adc	r4, r2

	add	r16, r0
	adc	r17, r1
	adc	r18, r4
	adc	r19, r5

	fmulsu	r23, r20     ; ( (signed)ah * bl ) << 1
	sbc	r19, r2
	add	r17, r0
	adc	r18, r1
	adc	r19, r2
	fmulsu	r21, r22     ; ( (signed)bh * al ) << 1
	sbc	r19, r2
	add	r17, r0
	adc	r18, r1
	adc	r19, r2

	ret


;***************************************************************************
; FUNCTION    - div24x24_24
; DESCRIPTION - 24 by 24 bit unsigned division
;               Divides two 24-bit numbers "r24:r23:r22" (dividend) and "r21:r20:r19" (divisor).
;               Result is placed in "r24:r23:r22" and the remainder in "r18:r17:r16".
; USAGE       - r24:r23:r22 = r24:r23:r22 / r21:r20:r19
; STATISTICS
;               Low registers used - 3 (r16,r17 r18)
;               High registers used - 6 (r19/r22, r20/r23, r21/r24,r19,r20,r21)

div24x24_24:
	clr	r16	        ;clear remainder Low byte
	clr r17
	sub	r18,r18     ;clear remainder High byte and carry
	ldi	r25,25	    ;init loop counter

d24u_1:	rol	r22		;shift left dividend
	rol r23
	rol	r24
	dec	r25		      ;decrement counter
	brne	d24u_2		;if done
	ret			        ;return

d24u_2:	rol	r16	  ;shift dividend into remainder
	rol r17
	rol	r18
	sub	r16,r19	    ;remainder = remainder - divisor
	sbc r17,r20
	sbc	r18,r21
	brcc	d24u_3		;if result negative
	add	r16,r19	    ;restore remainder
	adc r17,r20
	adc	r18,r21
	clc			        ;clear carry to be shifted into result
	rjmp d24u_1		  ;else

d24u_3:	sec			  ;set carry to be shifted into result
	rjmp d24u_1

	ret


;***************************************************************************
; FUNCTION    - div8u
; DESCRIPTION - 8/8 Bit Unsigned Division
;               Divide two register variables "dd8u" (dividend) and "dv8u" (divisor).
;               The result is placed in "dres8u" and the remainder in "drem8u".
; USAGE       - r21 = r21/r22
; STATISTICS
;               Cycles - 97
;               Words - 14
;               Low registers used - 1 (drem8u)
;               High registers used - 3 (dres8u/dd8u,dv8u,dcnt8u)
; REGISTERS
;               r20 - remainder
;               r21 - result
;               r21 - dividend
;               r22	- divisor
;               r23	- loop counter

div8u:
    sub	r20,r20	     ;clear remainder and carry
		ldi	r23,9	       ;init loop counter

d8u_1:
    rol	r21		       ;shift left dividend
		dec	r23		       ;decrement counter
		brne d8u_2		   ;if done
		ret			         ;return

d8u_2:
    rol	r20		       ;shift dividend into remainder
		sub	r20,r22	     ;remainder = remainder - divisor
		brcc d8u_3	 	   ;if result negative
		add	r20,r22	     ;restore remainder
		clc			         ;clear carry to be shifted into result
		rjmp d8u_1		   ;else

d8u_3: sec			     ;set carry to be shifted into result
		rjmp	d8u_1


;***************************************************************************
.equ	ClockTick_Task = 0
.equ	UpTime = -1

System_Monitor:
      rcall div24x24_24
			rcall div8u
			ret

.MACRO Start_Task             ;Start macro definition
		  sbi DDRD,(PD4 + @0)
		  sbi PORTD,(PD4 + @0)
.ENDMACRO

.MACRO End_Task               ;Start macro definition
		cbi PORTD,(PD4 +@0)
.ENDMACRO
;*** End of File ***
