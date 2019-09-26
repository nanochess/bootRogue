# Makefile contributed by jtsiomb

src = rogue.asm

.PHONY: all
all: rogue.img

rogue.img: $(src)
	nasm -f bin -l rogue.lst -o $@ $(src)

.PHONY: clean
clean:
	$(RM) rogue.img

.PHONY: runqemu
runqemu: os.img
	qemu-system-i386 -fda rogue.img
