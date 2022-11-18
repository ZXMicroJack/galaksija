include "galaksija.inc"

	org g_user_mem

	jp start

msg:	db "READ BYTES: "
  db 0
data: dw 32768
chksummsg:	db "CHECKSUM: "
  db 0
chksum: dw 0

errorreadingsectormsg:	db "ERROR READING SECTOR: "
  db 0

readsector:
  ld hl,0xfffc

  ld (hl),2
waitforbusy:
  bit 2,(hl)
  jr z,waitforbusy

  ld (hl),0
waitwhilebusy:
  bit 2,(hl)
  jr nz,waitwhilebusy

  bit 1,(hl)
  jr z,good
  or a ; clear cf
  scf
  ret

good:
  or a
  ret
  
readbyte:
  ; has data already, then jump straight to read
  ld hl,0xfffc
  bit 1,(hl)
  jr  z,doread
  scf
  ret

  ; read from fifo and clock next byte
doread:
  inc hl
  ld a,(hl)
  dec hl
  ld (hl),1
  ld (hl),0
  or a ; reset carry flag
  ret
  
hexchars:
  db "0123456789ABCDEF"

putnybble:
  and 0xf
  ld b,0
  ld c,a
  ld hl,hexchars
  adc hl,bc
  ld a,(hl)
  call g_putchr_rst_f
  ret
  
puthex:
  push af
  rra
  rra
  rra
  rra
  call putnybble
  pop af
  push af
  and 0xf
  call putnybble
  pop af
  ret
  
  
start:
  ld a,0x0c
  call g_putchr_rst_f

  ; zero checksum
  ld hl,chksum
  xor a
  ld (hl),a
  
  ; first read sector
  call readsector
  jr nc,drainfifo
  ld de,errorreadingsectormsg
  call g_printstr_f
  ret
  
drainfifo:
  ld de,0
  
drainfifo_loop:
  call readbyte
  jr  c,fin_drain
  
  push af
  push de
  call puthex
  pop de
  pop af
  
  ld hl,chksum
  xor (hl)
  ld (hl),a
  
  inc de
  jr drainfifo_loop

fin_drain:
  ld (data),de
  
  ; output READ BYTES: %d
  ld de,msg
	call g_printstr_f

	ld de,data
	call g_print_word_f
	
  ld a,0x0d
  call g_putchr_rst_f
  
  ; output CHECKSUM: %d
  ld de,chksummsg
	call g_printstr_f
	
	ld de,chksum
	call g_print_word_f
	
  ld a,0x0d
  call g_putchr_rst_f
	
  ret
