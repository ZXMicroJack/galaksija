;   org 0x0e93

exit_vector: equ 0xe93
l0e93h: equ 0xe93


  org 0x0edd
; can use b, hl, a
l0eddh:
	exx		;0edd
  ld hl,0xfffc
  bit 1,(hl)
  jr  z,doread

  ; signal read from sd card and wait for busy signal
  ld (hl),2
waitforbusy:
  bit 2,(hl)
  jr z,waitforbusy

  ; clear read signal from sd card and wait for clear busy signal
  ld (hl),0
waitwhilebusy:
  bit 2,(hl)
  jr nz,waitwhilebusy

  ; has data appeared in the fifo
  bit 1,(hl)
  jr z,doread
  jr end

  ; read from fifo and clock next byte
doread:
  inc hl
  ld a,(hl)
  dec hl
  ld (hl),1
  ld (hl),0

end:
  exx
  ld c,a
  jr exit_vector
