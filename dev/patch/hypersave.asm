; 'SAVE BYTE'
; ===========
; This function saves one byte to the audio cassette.

; Parameters:
;	A: byte to be saved
; Returns:
;	B: B = B + A
;	flags: output of CMP_HL_DE
; Destroys:
;	A

    org 0x0e68
;; SAVE_BYTE
l0e68h:
	exx		;0e68	Exchange BC,DE,HL with BC',DE',HL'

	ld c,010h	;0e69	Load 16 into C
	ld hl,0xfffd	;0e6b	Load latch address (2038h) into HL

;; SAVE_BYTE_LOOP
l0e6eh:
  ld (hl),a ; write data byte
  dec hl
  
  ld b,4 ; raise data ready flag
  ld (hl),b

waitforbusy:
  ld b,(hl) ; read data busy flag
  bit 2,b
  jr z,waitforbusy
  
  ld b,0 ; drop data ready flag
  ld (hl),b
  
waitforbusyclear:
  ld b,(hl) ; read data busy flag
  bit 2,b
  jr nz,waitforbusyclear

fillnops:
  jr 0x0e92
;   ds 0x0e92 - fillnops
;   fill with nops
;   
; 	exx		;0e92	Exchange BC,DE,HL with BC',DE',HL'

