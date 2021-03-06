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
        ; Revision date: Sep/22/2019. Creates monsters and items. Now has
        ;                             hp/exp. Food, armor, weapon, and traps
        ;                             works. Added battles.
        ; Revision date: Sep/23/2019. Lots of optimization.
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

GR_FOOD:        EQU 0x05
GR_WEAPON:      EQU 0x18
GR_ARMOR:       EQU 0x08
GR_TRAP:        EQU 0x04
GR_GOLD:        EQU 0x0f

YENDOR_LEVEL:   EQU 26

    %ifdef com_file
        org 0x0100
    %else
        org 0x7c00
    %endif

level:  equ 0x0fa0      ; Current level (starting at 0x01)
rnd:    equ 0x0fa1
yendor: equ 0x0fa3      ; 0x01 = Not found. 0xff = Found.
weapon: equ 0x0fa4
armor:  equ 0x0fa5
hp:     equ 0x0fa6      ; Current HP
max_hp: equ 0x0fa8      ; Max HP
exp:    equ 0x0faa      ; Current Exp
n_exp:  equ 0x0fac      ; Level to next Exp

monster: equ 0x0fae

start:
	mov ax,0x0002
	int 0x10
        mov ax,0xb800
	mov ds,ax
        mov es,ax

        mov di,rnd
        in al,0x40      ; Read timer counter
        stosw           ; Setup pseudorandom number generator

        mov ax,0x0001
        stosb           ; mov [yendor],al
        stosw           ; mov [weapon],ax ; and armor
        mov al,16
        stosw           ; mov [hp],ax
        stosw           ; mov [max_hp],ax
        mov al,0x00
        stosw           ; mov [exp],ax
        mov al,0x08
        stosw           ; mov [n_exp],ax
        mov al,0x01
generate_dungeon:
        mov [level],al
        mov ax,0x0a00
        call cls

        ;
        ; Start a dungeon
        ;
        mov bx,0x0800
        call random    
        add ax,ax
        xchg ax,bx
        cs mov bp,[bx+mazes]

        xor ax,ax
.4:
        cmp ax,BOX_WIDTH*3*2
        je .5
        cmp ax,BOX_WIDTH*3*2+ROW_WIDTH*BOX_HEIGHT
        jne .6
.5:     add ax,ROW_WIDTH*8-BOX_WIDTH*3*2
.6:
        call fill_column
        cmp ax,ROW_WIDTH*BOX_HEIGHT*2+BOX_WIDTH*3*2
        jb .4

        call random4
        mov si,3*ROW_WIDTH+12*2       
        mov di,19*ROW_WIDTH+12*2        
        shr al,1                     
        jnc .2
        xchg si,di
.2:     je .3
        add si,52*2
.3:
        mov byte [si],GR_LADDER

        cmp byte [level],YENDOR_LEVEL
        jb .1
        mov byte [di],GR_YENDOR
.1:
        mov di,11*ROW_WIDTH+38*2
game_loop:
        mov ax,game_loop
        push ax
        call update_hp

        ;
        ; Circle of light
        ;
        mov si,dirs
        mov cx,11
.7:     push di
        cs lodsb
        cbw
        add ax,ax
        add di,ax
        cmp word [di],0x0000+GR_FLOOR  ; To reveal?
        jnz .8                  ; No, don't "invent" things
        mov bx,0x6400
        call random
        cmp al,8                ; 8% chance of creating a monster/item
        jnb .8
        cmp al,5                ; 3% chance of creating a item
        jb .11
        mov bh,0x08
        call random
        jmp .12
.11:
        call random4
        add al,[level]
.9:
        sub al,0x05
        cmp al,0x16
        jge .9
        add al,0x04+(monsters-items) ; Offset into monsters label
.12:
        mov bx,items
        cs xlat
        mov byte [di],al
.8:
        mov byte [di+1],0x06
        pop di
        loop .7

        push word [di]
        mov word [di],0x0e00+GR_HERO
        mov ah,0x00
        int 0x16
        pop word [di]

        mov al,ah
        cmp al,0x01
        jne .1
	int 0x20
.1:     sub al,0x47
        jc move_over
        cmp al,0x0b
        jnc move_over
        mov bx,dirs
        cs xlat
        cbw
        mov bx,ax
        shl bx,1
        mov al,[di+bx]
        cmp al,0x41
        jb .17
        cmp al,0x5b
        jb battle
.17:
        mov si,walkable
        mov cx,10
.14:
        cs lodsb
        cmp al,[di+bx]
        cs lodsw
        jne .15
        lea di,[di+bx]
        cmp cl,6
        jb .16
        mov byte [di],GR_FLOOR
.16:    jmp ax

.15:
        loop .14
move_over:
        ret

amulet_found:
        mov byte [yendor],255
        ret

armor_found:
        inc byte [armor]
        ret
weapon_found:
        inc byte [weapon]
        ret
food_found:
        mov bx,0x0605
        jmp add_hp_random

trap_found:
        mov bx,0x06fa
add_hp_random:
        call random
add_hp: add ax,[hp]
        cmp ax,[max_hp]
        jl .1
        mov ax,[max_hp]
.1:     mov [hp],ax
        test ax,ax
        mov ax,0x0c0c
        js quit
update_hp:
        push di
        std
        mov di,0x0f9c
        mov ax,[max_hp]
        call show_number
        mov ax,0x0a2f
        stosw
        mov ax,[hp]
        call show_number
        mov ax,0x0a20
        stosw
        cld
        pop di
        ret

show_number:
        xor dx,dx
        mov cx,10
        div cx
        xchg ax,dx
        add ax,0x0a30
        stosw
        xchg ax,dx
        or ax,ax
        jnz show_number
        ret

ladder_found:
        mov al,[level]
        add al,[yendor]
        je .1           ; Jump if reached level zero
        jmp generate_dungeon

        ; Success! The light of day
.1:     mov ax,0x0f0f
quit:   call cls
        mov ah,0x00
        int 0x16
        int 0x20
cls:
        xor di,di
        mov cx,0x07d0
        rep stosw
        ret

battle:
        push bx
        xor bx,bx
.0:
        inc bx
        cs cmp al,[bx+monsters-1]
        jne .0
        xchg ax,bx
        mov [monster],al
        cmp al,0x16
        jb .1
        add ax,ax
.1:     xchg ax,bp
        ; Player's attack
.2:
        mov bh,[weapon]
        mov bl,0x01
        call random
        sub bp,ax
        jc .3
        ; Monster's attack
        mov bh,[monster]
        call random
        sub al,[armor]
        jc .4
        neg ax
        call add_hp
.4:
        mov ah,0x00
        int 0x16
        jmp .2

        ; Monster is dead
.3:
        pop bx
        lea di,[di+bx]
        mov byte [di],GR_FLOOR
        mov al,[monster]
        cbw
        inc ax
        shr ax,1
        add ax,[exp]
        cmp ax,[n_exp]
        jb .5
        shl word [n_exp],1
        shl word [max_hp],1
.5:     mov [exp],ax
        ret

        ;
        ; Fill a row with 3 rooms
        ;
fill_column:
        push ax
        add ax,4*ROW_WIDTH+(BOX_WIDTH/2-1)*2
        xchg ax,di
        shr bp,1
        mov ax,0x0000+GR_TUNNEL
        mov cx,BOX_WIDTH
        jnc .3
        push di
        rep stosw       ; Horizontal path
        pop di
.3:
        shr bp,1
        jnc .5
        mov cl,BOX_HEIGHT
.4:
        stosw           ; Vertical path
        add di,ROW_WIDTH-2
        loop .4
.5:     

        pop di

        mov bx,(BOX_MAX_WIDTH-2)*256+2
	call random
        xchg ax,cx
        mov bh,BOX_MAX_HEIGHT-2
	call random
	mov ch,al
        mov ax,BOX_MAX_HEIGHT*256+BOX_MAX_WIDTH
        sub ax,cx
        and ax,0xfefe
        xchg ax,bx
        mov al,ROW_WIDTH/2
        mul bh
        mov bh,0
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
        pop ax
        add ax,26*2
	ret

fill:	push cx
	push di
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
.2:     stosb
        inc di
        ret

random4:
        mov bx,0x0400
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
        add al,bl
        cbw
	ret

walkable:
        db GR_YENDOR
        dw amulet_found
        db GR_FOOD
        dw food_found
        db GR_GOLD      
        dw move_over
        db GR_WEAPON
        dw weapon_found
        db GR_ARMOR
        dw armor_found
        db GR_LADDER
        dw ladder_found
        db GR_TRAP
        dw trap_found
        db GR_TUNNEL
        dw move_over
        db GR_DOOR
        dw move_over
        db GR_FLOOR
        dw move_over

        ;
        ; Items
        ;
items:
        db GR_FOOD
        db GR_FOOD
        db GR_GOLD
        db GR_FOOD
        db GR_WEAPON
        db GR_TRAP
        db GR_ARMOR
        db GR_TRAP

	;
        ; Monsters in order of appearance
        ; (left side in earlier levels, right side in deep levels)
	;
monsters:
	db "KEBHISORZLCAQNYTWFPUGMXVJD"

dirs:   db -81,-80,-79,0
        db -1,0,1,0
        db 79,80,81

mazes:  dw $0aed
        dw $0be3
        dw $19a7
        dw $1b8d
        dw $42af
        dw $48ee
        dw $5363
        dw $59c7

    %ifdef com_file
    %else
        times 510-($-$$) db 0x4f
        db 0x55,0xaa            ; Make it a bootable sector
    %endif

