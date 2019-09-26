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
        ; Revision date: Sep/24/2019. Again lots of optimization. 596 bytes.
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

GR_TUNNEL:      EQU 0xb1
GR_DOOR:        EQU 0xce
GR_FLOOR:       EQU 0xfa

GR_HERO:        EQU 0x01

GR_LADDER:      EQU 0xf0
GR_TRAP:        EQU 0x04
GR_FOOD:        EQU 0x05
GR_ARMOR:       EQU 0x08
GR_YENDOR:      EQU 0x0c
GR_GOLD:        EQU 0x0f
GR_WEAPON:      EQU 0x18

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
        push ax
        in al,0x40      ; Read timer counter
        push ax         ; Setup pseudorandom number generator

        mov ax,0x0101
        push ax         ; level + yendor
        push ax         ; weapon + armor
        mov ah,0
        push ax         ; exp
        mov al,16
        push ax         ; n_exp
        push ax         ; hp
        push ax         ; max_hp
        mov al,0x02     ; ah already is zero
	int 0x10
        mov ax,0xb800
	mov ds,ax
        mov es,ax

        mov bp,sp
generate_dungeon:
        ;
        ; Start a dungeon
        ;
        mov bl,[bp+rnd]        
        and bx,0x000e
        cs mov si,[bx+mazes]

        xor ax,ax
        xor di,di
        mov ch,0x08     ; It's enough if it's greater than 0x07d0
        rep stosw
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
        mov bx,3*ROW_WIDTH+12*2       
        mov di,19*ROW_WIDTH+12*2        
        shl al,1                     
        jnc .2
        xchg bx,di
.2:     jns .3
        add bx,BOX_WIDTH*2*2
.3:
        mov byte [bx],GR_LADDER

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
        mov bx,0xfebf
.1:     add bx,0x00a0
        mov al,LIGHT_COLOR
        mov [bx+di],al
        mov [bx+di+2],al
        mov [bx+di+4],al
        js .1
        ;
        ; Show our hero
        ;
        push word [di]
        mov word [di],HERO_COLOR*256+GR_HERO
        mov ah,0x00
        int 0x16
        pop word [di]

        mov al,ah
        sub al,0x4c
        mov ah,0x02
        cmp al,0xff
        je .2
        cmp al,0x01
        je .2
        cmp al,0xfc
        je .3
        cmp al,0x04
        jne move_over
.3:
        mov ah,0x28
.2:
        imul ah
        xchg ax,bx
        lea bx,[di+bx]
        xchg bx,di
        mov al,[di]
        cmp al,GR_TUNNEL
        je move_over
        cmp al,GR_DOOR
        je move_over
        cmp al,GR_FLOOR
        je move_over
        cmp al,GR_TRAP
        je trap_found
        jb move_cancel
        cmp al,GR_LADDER
        je ladder_found
        mov byte [di],GR_FLOOR
        cmp al,GR_FOOD
        je food_found
        cmp al,GR_GOLD
        je move_over
        cmp al,GR_WEAPON
        je weapon_found
        cmp al,GR_ARMOR
        je armor_found
        cmp al,GR_YENDOR
        je amulet_found
        mov [di],al
        cmp al,0x5b
        jb battle
move_cancel:        
        xchg bx,di
move_over:
        ret

ladder_found:
        mov al,[bp+yendor]
        add [bp+level],al
        je $    ; Stall if reached level zero
        jmp generate_dungeon

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
        call random6
        jmp add_hp
trap_found:
        call random6
sub_hp: neg ax
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

battle:
        and al,0x1f
        cbw
        mov [bp+monster],ax
        xchg ax,si
        ; Player's attack
.2:
        mov bh,[bp+weapon]
        call random
        sub si,ax
        mov bh,[bp+monster]
        jc .3
        ; Monster's attack
        call random
        sub al,[bp+armor]
        jc .4
        call sub_hp
.4:
        mov ah,0x00
        int 0x16
        jmp .2

        ; Monster is dead
.3:
        mov byte [di],GR_FLOOR
        call random
        add ax,[bp+exp]
        cmp ax,[bp+n_exp]
        jb .5
        shl word [bp+n_exp],1
        shl word [bp+max_hp],1
.5:     mov [bp+exp],ax
        ret

        ;
        ; Fill a row with 3 rooms
        ;
fill_column:
        push ax
        add ax,4*ROW_WIDTH+(BOX_WIDTH/2-1)*2
        xchg ax,di
        shr si,1
        mov ax,0x0000+GR_TUNNEL
        mov cx,BOX_WIDTH
        jnc .3
        push di
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

        mov bh,BOX_MAX_WIDTH-2
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
        jns .1
        mov dh,GR_BOT_LEFT
        mov bx,GR_HORIZ*256+GR_BOT_RIGHT
fill:	push cx
	push di
	mov al,dh
        call door
.1:     mov al,bh
        call door
        dec cl
        jns .1
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
        mov bh,0x89
        call random
        cmp al,5                ; 3% chance of creating a item
        jb .11
        mov bx,items-5
        cmp al,12               ; 8% chance of creating a monster/item
        cs xlat
        jb .12
        mov al,GR_FLOOR
        jmp .12
.11:
        add al,[bp+level]
.9:
        sub al,0x05
        cmp al,0x17
        jge .9
        add al,0x44             ; Offset into ASCII letters
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

random6:
        mov bh,0x06

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
        cbw
        inc ax
	ret

        ;
        ; Items
        ;
items:
        db GR_FOOD
        db GR_GOLD
        db GR_FOOD
        db GR_TRAP
        db GR_WEAPON
        db GR_FOOD
        db GR_ARMOR

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

