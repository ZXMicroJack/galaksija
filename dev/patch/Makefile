default: hyperload.bin hyperload.hex

%.bin: %.asm
	z80asm -l -o$@ $^

%.hex: %.bin
	od -t x1 -w1 -v < $< | awk '{ print $$2 }' > $@

hyperload.bin: hyperload.asm
hyperload.hex: hyperload.bin

clean:
	rm *.bin *.hex
