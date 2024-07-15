.PHONY: build run
build:
	nasm boot.S -f bin -o bootloader.bin
	dd if=/dev/zero of=main.img bs=512 count=2880
	mkfs.fat -F 12 -n "NBOS" main.img
	dd if=bootloader.bin of=main.img conv=notrunc 
	mcopy -i main.img kern.bin "::kernel.bin"
run_dbg:	
	qemu-system-i386 -hda main.img -nographic -boot a -s -S
run: 
	qemu-system-i386 -hda main.img -nographic
debug:
	bochs -f bochs_cfg
kernel:
	nasm kern.asm -f bin -o kern.bin
