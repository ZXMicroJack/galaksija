include "galaksija.inc"

	org g_user_mem

	jp start

msg:	db "HELLO, WORLD!\r"

start:	ld de,msg
	call g_printstr_f
	ret
