#include <stdio.h>

// #define debug(a) printf a

#ifndef debug
#define debug(a)
#endif

unsigned short len = 0;
int lastch = 0;

unsigned char hdr[16];
int hdrpos = 0;
unsigned char chksum = 0;
int blockdone = 0;
void TapeSaveGalaksija(int ch) {
  if (blockdone) {
    printf("calc:%02X\n", (ch^0xff) ^ chksum);
    blockdone = 0;
  }
  
	chksum += ch;
	debug(("[%02X]\n", ch));
	if (hdrpos == 0 && ch == 0xa5) {
		hdr[hdrpos++] = ch;
	} else if (hdrpos < 5 && hdrpos > 0) {
		hdr[hdrpos++] = ch;
		if (hdrpos == 5) {
			unsigned short basic_start = (hdr[2] << 8) | hdr[1];
			unsigned short basic_end = (hdr[4] << 8) | hdr[3];

			if (basic_end < basic_start) hdrpos = 0;
			else {
        printf("start:%04X end:%04X len:%04X ", basic_start, basic_end, basic_end - basic_start);
				debug(("basic_start = %04X\n", basic_start));
				debug(("basic_end = %04X\n", basic_end));
				debug(("guess_len = %04X\n", basic_end - basic_start));
				len = basic_end - basic_start;
			}
		}
	} else if (len) {
		len --;
		if (len == 0) {
      printf("chksum:%02X ", chksum);
			debug(("chksum = %02X\n", chksum));
      blockdone = 1;
		}
	}
}


int galaksija = 0;
int wasteBytes = 0;
unsigned char xhdr[16];
int xhdrpos = 0;
int gtp(int ch) {
	debug(("{%02X:%c}", ch, (ch >= ' ' && ch < 128) ? ch : '?'  ));
	if (!galaksija) {
		if (wasteBytes) { wasteBytes --; debug(("w")); }
		else {
			xhdr[xhdrpos++] = ch;
			if (xhdr[0] == 0x10 && xhdrpos >= 2) {
				wasteBytes = 3 + xhdr[1];
				debug(("[waste %d]", wasteBytes));
				xhdrpos = 0;
			} else if (xhdr[0] == 0x00 && xhdrpos >= 5) {
				galaksija = 1;
			}
		}
		ch = 0x00;
	}
	return ch;
}

int main(void) {
	while (!feof(stdin)) {
		int ch = fgetc(stdin);
		if (ch >= 0) {
			TapeSaveGalaksija(gtp(ch));
		}
	}
	return 0;
}
