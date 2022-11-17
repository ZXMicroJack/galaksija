include "galaksija.inc"

	org g_user_mem

	jp start

msg:	db "HELLO, WORLD!\r"
data: dw 32768

start:
  ld a,0x0c
  call g_putchr_rst_f

  ld de,msg
	call g_printstr_f

	ld de,data
	call g_print_word_f
	
  ld a,0x0d
  call g_putchr_rst_f
  ret
