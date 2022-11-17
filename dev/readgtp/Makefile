stem=readgtp

default: $(stem).wav $(stem).bin $(stem).gtp

%.bin: %.asm
	z80asm -l -o$@ $^

%.gtp: %.bin
	../galaksija-tools-0.2.2/src/bin2gtp -o $@ $<

%.wav: %.gtp
	../galaksija-tools-0.2.2/src/gtp2wav -o $@ $<

run: $(stem).wav
	aplay $<

clean:
	rm *.bin *.gtp *.wav
