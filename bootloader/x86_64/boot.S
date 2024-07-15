;Start of the bootloader
org 0x7c00
bits 16

; [link] https://wiki.osdev.org/FAT#FAT_12
; FAT 12 HEADER
;

jmp short main
nop

oem:     						db 'MSWIN4.1' ; 8 bytes desc
bytes_per_sector:				dw 512
number_of_sector_per_cluster:   db 1
res_sectors:					dw 1
fat_coutn:						db 2
dir_entries_cnt:				dw 0xE0
total_sectors:					dw 2880		  ; 2880*512 = 1.44MB
media_desc:						db 0xF0
sectors_per_fat: 				dw 9          ; 9 sectors/fat
sectors_per_track:				dw 18
head_count: 					dw 2
hidden_sectors: 				dd 0
large_sector_cnt:				dd 0

; Extended boot record

drive_no: 						db 0						; 0x0 floppy as of
															; now
								db 0						; reserved
signature:						db 0x29						
vol_id:						    db 0x1, 0x3, 0x3, 0x7	; ser.no 	
vol_label: 						db 'nemo-os'
system_id:						db 'FAT12'



main:
	cli ; clear all the interrupts
	;Setup the segment registers
	xor ax,ax 
	mov ds,ax
	mov es,ax
	mov ss,ax

	mov sp,0x7c00 ;Setup stack from addr 0x7c00 
	; read something from disk
	mov  [drive_no], dl
	
	mov ax, 1
	mov cl, 1
	mov bx, 0x7E00
	call read_disk
	call print_nl
	mov si,banner
	call print

	cli
	hlt	

; For disk operations our bios will only use CHS addressing mode
; so we have to convert LBA(logical block addressing) to CHS(cylindrical
; head address) 
;
; IN(AX) 
; OUT(CH[bits 0-5(sector no.), CL[bits 6-15(cylinder)])
; OUT(DH [head])
; Reg modified AX, CX, DX

lba_to_chs:
	push ax
	push dx
    xor dx,dx
    div word [sectors_per_track]	; ax = LBA / sec_per_track
									; dx = LBA % sec_per_track
	inc dx							; +1 
    mov cx,dx						; cx = sector

	xor dx,dx
	div word [head_count]
	mov dh,dl						; dh = head
	mov ch,al 						; ch = cylinder (sector no.)
	shl ah,6
	or cl, ah						; Upper half of ah to cl

	pop ax
	mov dl,al
	pop ax
	ret
	
;
; Disk read
; [link] http://www.ctyme.com/intr/rb-0607.htm 
; IN(AX, CX, DX, es:bx) OUT()
; AX - LBA address
; CL - No. of sectors to read ( upto 128 )
; DL - Drive number
; es:bx - data buffer
;
read_disk:
	push ax
	push bx
	push cx
	push dx 
	push di
	
	push cx	
	call lba_to_chs
	pop ax 		

	mov ah,0x2 
	mov di, 3				; Retry counter
  retry:
	pusha 					; Save the prev value
	stc             		; Set carry flag, Can't trust BIOS on this
	int 0x13
	jnc success
	;If failed go reset the disk and retry
	popa
	call disk_reset
	dec di
	test di, di
	jnz retry
  fail:
	jmp read_failed
  success:
	; Disk read success
	mov si, disk_read_ok
	call print
	popa
	pop di
	pop dx 
	pop cx
	pop bx
	pop ax
	ret

; 
; Disk reset
; 
disk_reset: 
	pusha
	mov ah, 0x0
	stc 
	int 0x13
	jc fail
	popa
 	ret

read_failed:
	mov si,disk_read_failed
	call print
	jmp wait_reboot

wait_reboot:
	mov ah,0
	int 0x16
 	jmp 0xffff:0			; Jump to the begining of the BIOS
	cli
	hlt
; Print the values in SI register to tty
; IN(SI) OUT()
; reg modified AX,SI
print:
	pusha
	push si
  start:
	mov al,[si] ; Load a byte from si  
	cmp al,0
	je end
	mov ah,0xe
	int 0x10	; Print to console
	inc si
	jmp start
  end:
	popa
	pop si
	ret


; Print newline
; IN() OUT()
; Reg modified NONE 
print_nl:
	push ax
	push bx
	xor bh,bh
 	mov ax,0x0E0D
	int 0x10
	mov ax,0x0E0A
	int 0x10
	pop bx
	pop ax
	ret 



banner db "Starting my-os.....",0
disk_read_ok db "Disk read success",0
disk_read_failed db "Disk read failed!!!",0
times 510-($-$$) db 0
dw 0AA55h
