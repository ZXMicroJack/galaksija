; Constants

; Port locations for reading

CONSTANT	KEY_CODE, 0		; key code. special fn bit is at bit 7
CONSTANT	KEY_STICKY, 1		; KEY_STICKY bit is at bit 0
CONSTANT	ESC_STATE, 2		; esc_state is at bit 0

; Port locations for writing
CONSTANT	VIDEO_ADDR_L,0
CONSTANT	VIDEO_ADDR_H,1
CONSTANT	VIDEO_DATA,2
CONSTANT	VIDEO_WR, 3
CONSTANT	LINE_OUT, 4
CONSTANT	KEY_READ, 7


NAMEREG		sF, stack_pointer


; Scratch-pad RAM locations

CONSTANT	IMAGE_NUMBER, 0		; this scratch-pad location contains the number of image to be played


; Scratch-par RAM from 20h to end is reserved for stack

ADDRESS 0

Start:
	LOAD	sF, 20			; init stack pointer
	DISABLE INTERRUPT		; disable interrupts
	;ENABLE INTERRUPT		; enable interrupts

	; Init output lines
	
	LOAD	s0, 0
	OUTPUT	s0, VIDEO_WR
	OUTPUT	s0, KEY_READ
	LOAD	s0, 1
	OUTPUT	s0, LINE_OUT

dead:
	LOAD	s0, 1
	CALL	EraseScreen
	LOAD	s0, 0
	CALL	EraseScreen


	JUMP	dead


;------------------------------------------------------------------------------
; Erase screen with bit set in s0
EraseScreen:
	OUTPUT	s0, VIDEO_DATA
	
	LOAD	s0, 0
	LOAD	s1, D0

	LOAD	s2, 0
	LOAD	s3, 1

EraseScreen_l1:
	OUTPUT	s0, VIDEO_ADDR_L
	OUTPUT	s1, VIDEO_ADDR_H

	OUTPUT	s2, VIDEO_WR
	OUTPUT	s3, VIDEO_WR
	OUTPUT	s2, VIDEO_WR
		
	SUB	s0, 1
	JUMP	NZ, EraseScreen_l1
	SUB	s1, 1
	JUMP	NZ, EraseScreen_l1

	OUTPUT	s1, VIDEO_WR

	RETURN		
	
		
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------

; Interrupt handler
interrupt_handler:

	RETURNI ENABLE	; return from interrupt, enable interrupts

ADDRESS 3FF
	JUMP	interrupt_handler

