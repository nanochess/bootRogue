        ;
        ; bootRogue game in 512 bytes (boot sector)
        ;
        ; by Oscar Toledo G.
        ; http://nanochess.org/
        ;
        ; (c) Copyright 2019 Oscar Toledo G.
        ;
        ; Creation date: Sep/19/2019. Generates room boxes.
        ; Revision date: Sep/20/2019. Connect rooms. Allows to navigate.
        ;

        CPU 8086

ROW_WIDTH:	EQU $00A0
BOX_MAX_WIDTH:  EQU 23
BOX_MAX_HEIGHT: EQU 6
BOX_WIDTH:      EQU 26
BOX_HEIGHT:     EQU 8

GR_TOP_LEFT:    EQU 0xc9
GR_HORIZ:       EQU 0xcd
GR_TOP_RIGHT:   EQU 0xbb
GR_VERT:        EQU 0xba
GR_BOT_LEFT:    EQU 0xc8
GR_BOT_RIGHT:   EQU 0xbc

GR_DOOR:        EQU 0xce
GR_TUNNEL:      EQU 0xb1
GR_FLOOR:       EQU 0xfa
GR_HERO:        EQU 0x01

    %ifdef com_file
        org 0x0100
    %else
        org 0x7c00
    %endif

rnd:	equ 0x0fa0
level:  equ 0x0fa2
conn:   equ 0x0fa4

start:
	mov ax,0x0002
	int 0x10
        mov ax,0xb800
	mov ds,ax
        mov es,ax

        in al,0x40      ; Read timer counter
        mov [rnd],al    ; Setup pseudorandom number generator
        xor al,al
        mov [level],al

        ;
        ; Start a dungeon
        ;
        mov di,conn
        push di
        pop si
        ;
        ; Cell connection in map: (each cell only connects right/down)
        ;
        ;    0  1  2
        ;
        ;    3  4  5
        ;
        ;    6  7  8
        ;
        call random2    ; Top left corner connections
        stosb           ; Cell 0, random right/down connection
        call random2    ; Top right corner connections
        mov ah,al
        and ah,2        ; Cell 2, random down connection
        or al,2         ; Cell 1, always down, random right connection
        stosw
        call random2    ; Bottom left corner connections
        mov bl,al
        or al,1         ; Cell 3, always right, random down connection
        mov ah,3        ; Cell 4, always right and down connection
        stosw
        call random2    ; Bottom right corner connections
        mov ah,bl       
        and ah,1        ; Cell 6, random right connection.
        mov bl,al
        and al,2        ; Cell 5, random down connection.
        stosw
        mov al,bl       ; Cell 7, random right connection.
        and al,1
        mov ah,0        ; Cell 8, no connections.
        stosw

	xor di,di
	call fill_row
        call fill_row
	call fill_row

        mov si,11*ROW_WIDTH+38*2
game_loop:
        push word [si]
        mov word [si],0x0e00+GR_HERO
        mov ah,0x00
        int 0x16
        pop word [si]
        mov al,ah
        cmp al,0x01
        jne .1
	int 0x20
.1:     sub al,0x48
        jc .2
        cmp al,0x09
        jnc .2
        mov bx,dirs
        cs xlat
        cbw
        mov bx,ax
        shl bx,1
        mov al,[si+bx]
        cmp al,GR_FLOOR
        je .3
        cmp al,GR_DOOR
        je .3
        cmp al,GR_TUNNEL
        jne .2
.3:
        lea si,[si+bx]
.2:
        jmp game_loop

dirs:   db -80,0,0,-1,0,1,0,0,80

fill_row:
	call fill_column
	call fill_column
	call fill_column
	add di,ROW_WIDTH*7+4
	ret

fill_column:
        push di
        add di,4*ROW_WIDTH+(BOX_WIDTH/2-1)*2
        lodsb
        shr al,1
        mov ax,0x0700+GR_TUNNEL
        mov cx,BOX_WIDTH
        jnc .3
        push di
.2:
        rep stosw
        pop di
.3:     
        jz .5
        mov cl,BOX_HEIGHT
.4:
        stosw
        add di,ROW_WIDTH-2
        loop .4
.5:     

        pop di

        mov bh,BOX_MAX_WIDTH-2
	call random
        inc ax
        inc ax
	mov cl,al
        mov bh,BOX_MAX_HEIGHT-2
	call random
        inc ax
        inc ax
	mov ch,al
	mov al,BOX_MAX_WIDTH
	sub al,cl
        and al,0xfe
        cbw
        xchg ax,bx
	mov al,BOX_MAX_HEIGHT
	sub al,ch
	shr al,1
	mov ah,ROW_WIDTH
	mul ah
	add ax,bx
	push di
	add di,ax
        mov dx,GR_TOP_LEFT*256+GR_HORIZ
        mov bh,GR_TOP_RIGHT
	call fill
.1:
        mov dx,GR_VERT*256+GR_FLOOR
        mov bh,GR_VERT
	call fill
	dec ch
	jnz .1
        mov dx,GR_BOT_LEFT*256+GR_HORIZ
        mov bh,GR_BOT_RIGHT
	call fill
	pop di
	add di,26*2
	ret

fill:	push cx
	push di
        mov ah,0x06
	mov al,dh
        call door
        mov ch,0
.1:	mov al,dl
        call door
        loop .1
	mov al,bh
        call door
	pop di
	pop cx
	add di,0x00a0
	ret

door:
        cmp al,GR_HORIZ
        jz .1
        cmp al,GR_VERT
        jnz .2
.1:     cmp byte [di],GR_TUNNEL
        jnz .2
        mov al,GR_DOOR
.2:     stosw
        ret

random2:
        mov bh,4
.1:
        call random
        or al,al
        jz .1
        ret

random:
	mov ax,[rnd]
	push cx
	mov cx,7841
	mul cx
	add ax,83
	mov [rnd],ax
	pop cx
 
;       rdtsc           ; Would make it dependent on Pentium II

;       in al,(0x40)    ; Only works for slow requirements.

	xor ah,ah
	div bh
	mov al,ah
	ret

