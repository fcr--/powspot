#include <atari.h>
#include <stdio.h>
#include <dirent.h>
#include <conio.h>
#include <peekpoke.h>
#include <errno.h>
#include <string.h>
#include <stdbool.h>
#include <stdlib.h>

typedef unsigned word;
typedef unsigned char byte;

// 8640 == 320*192*(9/8)/8
#define MAX_BUF 8640
static byte buffer[MAX_BUF];
static word compressed_length;

static byte * screenmem;


bool load_page(word num) {
  static char filename[17];
  static FILE * f;
  POKE(710, 0x10); // background
  sprintf(filename, "D:PAGE%d.IMZ", num);
  f = fopen(filename, "r");
  if (!f) {
    POKE(710, 0); // background
    return false;
  }
  compressed_length = fread(buffer, 1, MAX_BUF, f);
  fclose(f);
  POKE(710, 0); // background
  return true;
}

void display_compressed_page() {
  static word i;
  static byte flags_count, flags;
  static byte * screenmemwp; // tmp

  POKE(710, 0xC0); // background
  flags_count = 0;
  screenmemwp = screenmem;
  memset(screenmem, 0, 7680);
  for (i = 0; i < compressed_length; i++) {
    if (!flags_count) {
      flags = buffer[i];
      flags_count = 8;
    } else if ((flags & 1) == 0) {
      *screenmemwp++ = buffer[i];
      flags >>= 1;
      flags_count--;
    } else {
      static word len, j;
      static byte off;
      len = buffer[i]; off = buffer[++i];
      for (j = len + 3; j; j--) {
	*screenmemwp = *(byte*)((int)screenmemwp - off - 1);
	screenmemwp++;
      }
      flags >>= 1;
      flags_count--;
    }
  }
  POKE(710, 0);
}

#if 0
// Example: filedump("D:PAGE0.IMZ", 0, 128);
void bindump(char * filename, int off, int len) {
  int i;
  FILE * fd = fopen(filename, "r");
  if (!fd) {
    printf("Error %d\n", errno);
    return;
  }
  if (off) fseek(fd, off, SEEK_SET);
  len = fread(buffer, 1, len, fd);
  fclose(fd);
  for (i = 0; i < len; i++) {
    if ((i & 0xf) == 0) printf("%04X: ", i);
    revers(i & 1);
    cprintf("%02X", buffer[i]);
    if ((i & 0xf) == 0xf) { revers(0); printf("\n"); }
  }
}
#endif

void main(void) {
  static word page;
  static char c;
  static bool forward, preloaded;
  for (;;) {
    page = 0;
    forward = true;
    {
      DIR * d;
      struct dirent * de;
      byte n = 0;
      printf("         PowSpot!  (by FCR)\n\nAvailable files:\n");
      d = opendir("D:*.*");
      while (de = readdir(d)) {
	printf(" %-12s", de->d_name);
	if (n++ == 2) {printf("\n"); n=0;}
      }
      if (n) printf("\n");
      closedir(d);
    }
    printf("\nGo to next slide using SPACE or RETURN,\n"
	"backwards with DELETE, and back to this\n"
	"menu with ESC.\n\n");
    POKE(710, 0x94); // restore background
    printf("Enter page num. or RETURN to continue!\n> ");
    cursor(1);
    fgets(buffer, MAX_BUF, stdin);
    page = atoi(buffer);
    _graphics(24);
    cursor(0);
    screenmem = *(byte**)88;
    POKE(709, 0x0F); // foreground
    POKE(710, 0x10); // background
    if (!load_page(page)) {
      page = 0;
      if (!load_page(0)) continue;
    }
    display_compressed_page();
    preloaded = load_page(page + 1);
    for (;;) {
      while(!kbhit());
      c = cgetc();
      if (((c&0x7f) == ' ' || c == '\n') && (preloaded || !forward)) {
	page++;
	if (!forward) {
	  load_page(page);
	  forward = true;
	}
	display_compressed_page();
	preloaded = load_page(page + 1);
      } else if (c == CH_DEL && page) {
	page--;
	if (forward) {
	  load_page(page);
	  forward = false;
	}
	display_compressed_page();
	preloaded = page > 0 && load_page(page - 1);
      } else if (c == CH_ESC) {
	break;
      }
      while (kbhit()) cgetc();
    }
  }
}
