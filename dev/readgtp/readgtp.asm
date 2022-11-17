include "galaksija.inc"

	org g_user_mem

	jp start

msg:	db "READ BYTES: "
data: dw 32768
chksummsg:	db "CHECKSUM: "
chksum: dw 0
readsizemsg:	db "READSIZE: "
readsize: dw start-readbyte

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

  ; zero checksum
  ld hl,chksum
  xor a
  ld (hl),a

  ; read 1024 bytes
  ld de,0
  ld b,4
readloop1:
  push bc
  ld b,0
readloop2:
  call readbyte
  ld hl,chksum
  xor (hl)
  ld (hl),a
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
  
  ld de,chksummsg
	call g_printstr_f
	
	ld de,chksum
	call g_print_word_f
	
  ld a,0x0d
  call g_putchr_rst_f
	
  ld de,readsizemsg
	call g_printstr_f
	
	ld de,readsize
	call g_print_word_f
	
  ld a,0x0d
  call g_putchr_rst_f
  
  ret
