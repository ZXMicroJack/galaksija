default: hyperload.bin hyperload.hex hypersave.bin hypersave.hex

%.bin: %.asm
	z80asm -l -o$@ $^

%.hex: %.bin
	od -t x1 -w1 -v < $< | awk '{ print $$2 }' > $@

hyperload.bin: hyperload.asm
hyperload.hex: hyperload.bin

hypersave.bin: hypersave.asm
hypersave.hex: hypersave.bin

clean:
	rm *.bin *.hex
