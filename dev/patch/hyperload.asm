  org 0x0e93
exit_vector:

  org 0x0edd
readbyte:
  ; has data already, then jump straight to read
  push hl
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
  ld c,(hl)
  dec hl
  ld (hl),1
  ld (hl),0

  ld a,c
end:
  pop hl
  jr exit_vector
;   jp 0x0e93

  
