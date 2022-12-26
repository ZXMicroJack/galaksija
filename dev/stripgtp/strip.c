#include <stdio.h>


unsigned short len = 0;
int lastch = 0;

unsigned char hdr[16];
int hdrpos = 0;
unsigned char chksum = 0;
void TapeSaveGalaksija(int ch) {
	chksum += ch;
	printf("[%02X]\n", ch);
	if (hdrpos == 0 && ch == 0xa5) {
		hdr[hdrpos++] = ch;
	} else if (hdrpos < 5 && hdrpos > 0) {
		hdr[hdrpos++] = ch;
		if (hdrpos == 5) {
			unsigned short basic_start = (hdr[2] << 8) | hdr[1];
			unsigned short basic_end = (hdr[4] << 8) | hdr[3];

			if (basic_end < basic_start) hdrpos = 0;
			else {
				printf("basic_start = %04X\n", basic_start);
				printf("basic_end = %04X\n", basic_end);
				printf("guess_len = %04X\n", basic_end - basic_start);
				len = basic_end - basic_start;
			}
		}
	} else if (len) {
		len --;
		if (len == 0) {
			printf("chksum = %02X\n", chksum);
		}
	}
}


int galaksija = 0;
int wasteBytes = 0;
unsigned char xhdr[16];
int xhdrpos = 0;
void gtp(int ch) {
	printf("{%02X:%c}", ch, (ch >= ' ' && ch < 128) ? ch : '?'  );
	if (!galaksija) {
		if (wasteBytes) { wasteBytes --; printf("w"); }
		else {
			xhdr[xhdrpos++] = ch;
			if (xhdr[0] == 0x10 && xhdrpos >= 2) {
				wasteBytes = 3 + xhdr[1];
				printf("[waste %d]", wasteBytes);
				xhdrpos = 0;
			} else if (xhdr[0] == 0x00 && xhdrpos >= 5) {
				galaksija = 1;
			}
		}
		TapeSaveGalaksija(0x00);
	} else TapeSaveGalaksija(ch);
}

int main(void) {
	while (!feof(stdin)) {
		int ch = fgetc(stdin);
		if (ch >= 0) {
			gtp(ch);
		}
	}
	return 0;
}
