stem=readgtp

default: $(stem).wav

%.bin: %.asm
	z80asm -o$@ $^

%.gtp: %.bin
	../galaksija-tools-0.2.2/src/bin2gtp -o $@ $<

%.wav: %.gtp
	../galaksija-tools-0.2.2/src/gtp2wav -o $@ $<

run: $(stem).wav
	aplay $<

clean:
	rm *.bin *.gtp *.wav
