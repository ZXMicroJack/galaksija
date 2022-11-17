include "galaksija.inc"

	org g_user_mem

	jp start

msg:	db "READ BYTES: "
data: dw 32768
nrzeros: dw 0

readbyte:
  ld hl,0xfffc
  ld a,(hl)
  bit 1,a
  jr  z,doread

  ld (hl),2
  
waitforbusy:
  ld a,(hl)
  bit 2,a
  jr z,waitforbusy

  ld (hl),0

waitwhilebusy:
  ld a,(hl)
  bit 2,a
  jr nz,waitwhilebusy
  
  bit 1,a
  jr z,doread

  ; read has been performed and there is still no data
  scf
  ret
  

doread:
  inc hl
  ld a,(hl)
  dec hl
  ld (hl),1
  ld (hl),0
  or a ; reset carry flag
  ret
  
start:
  ld a,0x0c
  call g_putchr_rst_f


  ld de,0
  ld b,4
readloop1:
  push bc
  ld b,0
readloop2:
  call readbyte
  jr c,dontincrement
  inc de
dontincrement:
  djnz readloop2
  pop bc
  djnz readloop1
  
  push de
  ld de,msg
	call g_printstr_f

	; transfer de to memory
	pop de
  ld hl,data
  ld a,e
  ld (hl),a
  ld a,d
  inc hl
  ld (hl),a
  dec hl
  push hl
  pop de

	ld de,data
	call g_print_word_f
	
  ld a,0x0d
  call g_putchr_rst_f
  ret
