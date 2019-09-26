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

LIGHT_COLOR:    EQU 0x06
HERO_COLOR:     EQU 0x0e

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

monster: equ 0x000e
rnd:    equ 0x000c
level:  equ 0x000a      ; Current level (starting at 0x01)
yendor: equ 0x000b      ; 0x01 = Not found. 0xff = Found.
weapon: equ 0x0008
armor:  equ 0x0009
exp:    equ 0x0006      ; Current Exp
n_exp:  equ 0x0004      ; Level to next Exp
hp:     equ 0x0002      ; Current HP
max_hp: equ 0x0000      ; Max HP

start:
	mov ax,0x0002
	int 0x10
        mov ax,0xb800
	mov ds,ax
        mov es,ax

        push ax
        in al,0x40      ; Read timer counter
        push ax         ; Setup pseudorandom number generator

        mov ax,0x0101
        push ax         ; level + yendor
        push ax         ; weapon + armor
        mov ah,0
        push ax         ; exp
        mov al,0x08
        push ax         ; n_exp
        mov al,16
        push ax         ; hp
        push ax         ; max_hp
        mov bp,sp
generate_dungeon:
        xor ax,ax
        xor di,di
        mov cx,0x07d0
        rep stosw

        ;
        ; Start a dungeon
        ;
        mov al,[bp+rnd]         ; ah is zero already
        and al,0x0e
        xchg ax,bx
        cs mov si,[bx+mazes]

        xor ax,ax
.4:
        push ax
        call fill_column
        pop ax
        add ax,BOX_WIDTH*2
        cmp al,0x9c
        jne .5
        add ax,ROW_WIDTH*BOX_HEIGHT-BOX_WIDTH*3*2
.5:
        cmp ax,ROW_WIDTH*BOX_HEIGHT*3
        jb .4

        mov ax,[bp+rnd]
        mov si,3*ROW_WIDTH+12*2       
        mov di,19*ROW_WIDTH+12*2        
        shl al,1                     
        jnc .2
        xchg si,di
.2:     jns .3
        add si,BOX_WIDTH*2*2
.3:
        mov byte [si],GR_LADDER

        cmp byte [bp+level],YENDOR_LEVEL
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
.7:     cs lodsb
        cbw
        xchg ax,bx
        shl bx,1
        mov byte [bx+di+1],LIGHT_COLOR
        loop .7

        ;
        ; Show our hero
        ;
        push word [di]
        mov word [di],HERO_COLOR*256+GR_HERO
        mov ah,0x00
        int 0x16
        pop word [di]

        mov al,ah
        sub al,0x47
        jc move_over
        cmp al,0x0b
        jnc move_over
        mov bx,dirs
        cs xlat
        cbw
        xchg ax,bx
        shl bx,1
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
        mov al,[di+bx]
        cmp al,0x5b
        jb battle
move_over:
        ret

battle:
        lea di,[di+bx]
        and al,0x1f
        cbw
        mov [bp+monster],ax
        xchg ax,si
        ; Player's attack
.2:
        mov bh,[bp+weapon]
        mov bl,0x01
        call random
        sub si,ax
        jc .3
        ; Monster's attack
        mov bh,[bp+monster]
        call random
        sub al,[bp+armor]
        jc .4
        neg ax
        call add_hp
.4:
        mov ah,0x00
        int 0x16
        jmp .2

        ; Monster is dead
.3:
        mov byte [di],GR_FLOOR
        mov ax,[bp+monster]
        inc ax
        shr ax,1
        add ax,[bp+exp]
        cmp ax,[bp+n_exp]
        jb .5
        shl word [bp+n_exp],1
        shl word [bp+max_hp],1
.5:     mov [bp+exp],ax
        ret

amulet_found:
        neg byte [bp+yendor]
        ret

armor_found:
        inc byte [bp+armor]
        ret

weapon_found:
        inc byte [bp+weapon]
        ret

food_found:
        mov bl,0x05
        db 0xb8         ; Jump two bytes using mov ax,imm16
trap_found:
        mov bl,0xfa
add_hp_random:
        mov bh,0x06
        call random
add_hp: add ax,[bp+hp]
        js $    ; Stall if dead
        cmp ax,[bp+max_hp]
        jl .1
        mov ax,[bp+max_hp]
.1:     mov [bp+hp],ax
update_hp:
        mov bx,0x0f9c
        mov ax,[bp+max_hp]
        call show_number
        mov ax,[bp+hp]
show_number:
        xor dx,dx
        mov cx,10
        div cx
        add dx,0x0a30
        mov [bx],dx
        dec bx
        dec bx
        or ax,ax
        jnz show_number
        mov [bx],ax
        dec bx
        dec bx
        ret

ladder_found:
        mov al,[bp+yendor]
        add [bp+level],al
        je $    ; Stall if reached level zero
        jmp generate_dungeon

        ;
        ; Fill a row with 3 rooms
        ;
fill_column:
        push ax
        add ax,4*ROW_WIDTH+(BOX_WIDTH/2-1)*2
        xchg ax,di
        shr si,1
        mov ax,0x0000+GR_TUNNEL
        jnc .3
        push di
        mov cl,BOX_WIDTH
        rep stosw       ; Horizontal path
        pop di
.3:
        shr si,1
        jnc .5
        mov cl,BOX_HEIGHT
.4:
        stosb           ; Vertical path
        add di,ROW_WIDTH-1
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
	add di,ax
        mov dh,GR_TOP_LEFT
        mov bx,GR_HORIZ*256+GR_TOP_RIGHT
	call fill
.1:
        mov dh,GR_VERT
        mov bx,GR_FLOOR*256+GR_VERT
	call fill
	dec ch
        jne .1
        mov dh,GR_BOT_LEFT
        mov bx,GR_HORIZ*256+GR_BOT_RIGHT
fill:	push cx
	push di
	mov al,dh
        call door
        mov ch,0
.1:     mov al,bh
        call door
        loop .1
        mov al,bl
        call door
	pop di
	pop cx
	add di,0x00a0
	ret

door:
        cmp al,GR_FLOOR
        jne .3
        push bx
        mov bx,0x6400
        call random
        cmp al,3                ; 3% chance of creating a item
        jb .11
        cmp al,8                ; 8% chance of creating a monster/item
        mov al,GR_FLOOR
        jnb .12
        mov bh,0x08
        call random
        mov bx,items
        cs xlat
        jmp .12
.11:
        mov bx,0x0400
        call random
        add al,[bp+level]
.9:
        sub al,0x05
        cmp al,0x16
        jge .9
        add al,0x45             ; Offset into ASCII letters
.12:    pop bx
.3:
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

random:
        mov ax,7841
        mul word [bp+rnd]
	add ax,83
        mov [bp+rnd],ax
 
;       rdtsc           ; Would make it dependent on Pentium II

;       in al,(0x40)    ; Only works for slow requirements.

	xor ah,ah
	div bh
	mov al,ah
        add al,bl
        cbw
	ret

walkable:
        db GR_FOOD
        dw food_found
        db GR_GOLD      
        dw move_over
        db GR_WEAPON
        dw weapon_found
        db GR_ARMOR
        dw armor_found
        db GR_YENDOR
        dw amulet_found
        db GR_TRAP
        dw trap_found
        db GR_LADDER
        dw ladder_found
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

