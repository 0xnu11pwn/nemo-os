.PHONY: build_bootloader build_kernel all run_bootloader


build_bootloader:
	make -C bootloader/x86_64/ build 

run_bootloader:
	make -C bootloader/x86_64/ run
