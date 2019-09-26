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
        ; Revision date: Sep/21/2019. Added ladders to go down/up. Shows
        ;                             Amulet of Yendor at level 26. Added
        ;                             circle of light.
        ;

        CPU 8086

ROW_WIDTH:	EQU 0x00A0
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
GR_LADDER:      EQU 0xf0
GR_YENDOR:      EQU 0x0c

YENDOR_LEVEL:   EQU 26

    %ifdef com_file
        org 0x0100
    %else
        org 0x7c00
    %endif

rnd:	equ 0x0fa0
level:  equ 0x0fa2      ; Current level (starting at 0x01)
yendor: equ 0x0fa3      ; 0x01 = Not found. 0xff = Found.
conn:   equ 0x0fa4

start:
	mov ax,0x0002
	int 0x10
        mov ax,0xb800
	mov ds,ax
        mov es,ax

        in al,0x40      ; Read timer counter
        mov [rnd],al    ; Setup pseudorandom number generator
        mov al,0x01
        mov [yendor],al
generate_dungeon:
        mov [level],al
        mov ax,0x0f20
        call cls

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
        call random3    ; Top left corner connections
        stosb           ; Cell 0, random right/down connection
        call random3    ; Top right corner connections
        mov ah,al
        and ah,2        ; Cell 2, random down connection
        or al,2         ; Cell 1, always down, random right connection
        stosw
        call random3    ; Bottom left corner connections
        mov bl,al
        or al,1         ; Cell 3, always right, random down connection
        mov ah,3        ; Cell 4, always right and down connection
        stosw
        call random3    ; Bottom right corner connections
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

        mov bh,8
        call random
        and al,0xfe
        cbw
        xchg ax,bx
        cs mov si,[bx+ladder_positions]
        mov byte [si],GR_LADDER

        mov al,[level]
        cmp al,YENDOR_LEVEL
        jb .1
        add bx,2
        and bx,6
        cs mov si,[bx+ladder_positions]
        mov byte [si],GR_YENDOR
.1:
        mov di,11*ROW_WIDTH+38*2
game_loop:
        push word [di]

        ;
        ; Circle of light
        ;
        mov si,dirs
        mov cx,11
.7:     cs lodsb
        cbw
        add ax,ax
        xchg ax,bx
        mov byte [bx+di+1],0x06
        loop .7

        mov word [di],0x0e00+GR_HERO
        mov ah,0x00
        int 0x16
        pop word [di]
        mov al,ah
        cmp al,0x01
        jne .1
	int 0x20
.1:     sub al,0x47
        jc .2
        cmp al,0x0b
        jnc .2
        mov bx,dirs
        cs xlat
        cbw
        mov bx,ax
        shl bx,1
        mov al,[di+bx]
        cmp al,GR_YENDOR
        je .6
        cmp al,GR_LADDER
        je .4
        cmp al,GR_FLOOR
        je .3
        cmp al,GR_DOOR
        je .3
        cmp al,GR_TUNNEL
        jne .2
.3:
        lea di,[di+bx]
.2:
        jmp game_loop

.6:     mov byte [yendor],255
        lea di,[di+bx]
        mov byte [di],GR_FLOOR
        jmp game_loop

.4:
        mov al,[level]
        add al,[yendor]
        je .5
        jmp generate_dungeon

        ; Sucess!
.5:     mov ax,0x0f0f
        call cls
        jmp game_loop

cls:
        xor di,di
        mov cx,0x07d0
        rep stosw
        ret

dirs:   db -81,-80,-79,0,
        db -1,0,1,0
        db 79,80,81

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
        mov ax,0x0000+GR_TUNNEL
        mov cx,BOX_WIDTH
        jnc .3
        push di
.2:
        rep stosw
        pop di
.3:     
        je .5
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
        xchg ax,cx
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
        jne .1
        mov dx,GR_BOT_LEFT*256+GR_HORIZ
        mov bh,GR_BOT_RIGHT
	call fill
	pop di
	add di,26*2
	ret

fill:	push cx
	push di
        mov ah,0x00
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
        je .1
        cmp al,GR_VERT
        jne .2
.1:     cmp byte [di],GR_TUNNEL
        jne .2
        mov al,GR_DOOR
.2:     stosw
        ret

random3:
        mov bh,3
        call random
        inc ax
        ret

random:
        mov ax,7841
        mul word [rnd]
	add ax,83
	mov [rnd],ax
 
;       rdtsc           ; Would make it dependent on Pentium II

;       in al,(0x40)    ; Only works for slow requirements.

	xor ah,ah
	div bh
	mov al,ah
	ret

    %if 0
	;
	; Monsters in order of appearance
	;
monsters:
	db "KEBHISORZLCAQNYTWFPUGMXVJD"

attack:
	db 0x00	; Aquator
	db 0x12	; Bat
	db 0x26	; Centaur
	db 0x5a	; Dragon
	db 0x12	; Emu
	db 0x00	; Venus flytrap
	db 0x93	; Griffin
	db 0x18	; Hobgoblin
	db 0x12	; Ice monster
	db 0x54	; Jabberwock
	db 0x14	; Kestral
	db 0x12	; Leprechaun
	db 0x3b	; Medusa
	db 0x00	; Nymph
	db 0x18	; Orc
	db 0x44	; Phantom
	db 0x42	; Quagga
	db 0x16	; Rattlesnake
	db 0x13	; Slime
	db 0x38	; Troll
	db 0xb3	; Ur-vile
	db 0x1a	; Vampire
	db 0x16	; Wraith
        db 0x34 ; Xeroc
	db 0x26	; Yeti
	db 0x18	; Zombie
    %endif

ladder_positions:
        dw 3*ROW_WIDTH+12*2
        dw 3*ROW_WIDTH+64*2
        dw 19*ROW_WIDTH+12*2
        dw 19*ROW_WIDTH+64*2

