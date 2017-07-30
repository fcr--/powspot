all: powspot.atr

include Images.mak
include ImagesNum.mak

powspot.atr: floppy/AUTORUN.SYS floppy/DOS.SYS $(foreach i,$(IMGNUMS),floppy/PAGE$i.IMZ) ImagesNum.mak
	@# atrcopy does a bad job of creating bootable disk images... we use dir2atr instead:
	@#~/.local/bin/atrcopy powspot.atr create -f dos2ed
	@#dd if=bootsectors of=powspot.atr seek=1 bs=16 conv=notrunc
	@#cd floppy && ~/.local/bin/atrcopy ../powspot.atr add DOS.SYS DUP.SYS AUTORUN.SYS
	@#cd floppy && ~/.local/bin/atrcopy ../powspot.atr add $(foreach d,$(IMGNUMS),PAGE$d.IMG)
	$(DIR2ATR) -b Dos25 1040 powspot.atr floppy/

floppy/PAGE%.IMG:
	luajit make.lua buildImage $@ $<
floppy/PAGE%.IMZ:
	luajit make.lua buildCompressedImage $@ $<

floppy/DOS.SYS:
	mkdir -p floppy
	$(ATRCOPY) tmp.atr create -f dos2ed+2.5
	@#dd if=tmp.atr of=bootsectors count=48 skip=1 bs=16
	cd floppy && $(ATRCOPY) ../tmp.atr extract DOS.SYS
	rm tmp.atr

floppy/AUTORUN.SYS: powspot.c
	mkdir -p floppy
	cl65 -t atari -O -Wl -D__RESERVED_MEMORY__=0x2002 powspot.c -o floppy/AUTORUN.SYS

clean:
	rm -rf bootsectors powspot.o powspot.atr floppy

ImagesNum.mak: Images.mak
	echo "# This file was autogenerated, do not edit" > ImagesNum.mak
	echo -n IMGNUMS := >> ImagesNum.mak
	{ i=0; for x in $(IMAGES); do echo -n " $$((i++))"; done; } >> ImagesNum.mak
	echo >> ImagesNum.mak
	echo >> ImagesNum.mak
	@# enumerate images:
	{ i=0; for x in $(IMAGES); do echo "floppy/PAGE$$((i++)).IMZ: $$x"; done; } >> ImagesNum.mak

