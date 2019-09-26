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

rnd:	equ 0x0fa0
level:  equ 0x0fa2      ; Current level (starting at 0x01)
yendor: equ 0x0fa3      ; 0x01 = Not found. 0xff = Found.
weapon: equ 0x0fa4
armor:  equ 0x0fa5
hp:     equ 0x0fa6      ; Current HP
max_hp: equ 0x0fa8      ; Max HP
exp:    equ 0x0faa      ; Current Exp
n_exp:  equ 0x0fac      ; Level to next Exp

monster: equ 0x0fae
conn:   equ 0x0fae

start:
	mov ax,0x0002
	int 0x10
        mov ax,0xb800
	mov ds,ax
        mov es,ax

        in al,0x40      ; Read timer counter
        mov [rnd],al    ; Setup pseudorandom number generator

        mov ax,0x0001
        mov [yendor],al
        mov [weapon],ax
        mov al,20
        mov [hp],ax
        mov [max_hp],ax
        mov al,0x00
        mov [exp],ax
        mov al,0x08
        mov [n_exp],ax
        mov al,0x01
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
        mov cl,al
        or al,1         ; Cell 3, always right, random down connection
        mov ah,3        ; Cell 4, always right and down connection
        stosw
        call random3    ; Bottom right corner connections
        mov ah,cl       
        and ah,1        ; Cell 6, random right connection.
        mov cl,al
        and al,2        ; Cell 5, random down connection.
        stosw
        mov al,cl       ; Cell 7, random right connection.
        and ax,1        ; Cell 8, no connections.
        stosw

        mov di,-(ROW_WIDTH*7+4)
        call fill_row   ; Top row of rooms
        call fill_row   ; Middle row of rooms
        call fill_row   ; Bottom row of rooms

        mov bx,0x0800
        call random
        and al,0xfe
        cbw
        xchg ax,bx
        cs mov si,[bx+ladder_positions]
        mov byte [si],GR_LADDER

        mov al,[level]
        cmp al,YENDOR_LEVEL
        jb .1
        add bl,2
        and bl,6
        cs mov si,[bx+ladder_positions]
        mov byte [si],GR_YENDOR
.1:
        mov di,11*ROW_WIDTH+38*2
game_loop:
        mov ax,game_loop
        push ax
        call update_hp
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
        mov ax,[bx+di]
        cmp ax,0x0000+GR_FLOOR  ; To reveal?
        jnz .8                  ; No, don't "invent" things
        push bx
        mov bx,0x6400
        call random
        cmp al,8                ; 8% chance of creating a monster/item
        pop bx
        jnb .8
        push bx
        cmp al,5                ; 3% chance of creating a item
        jb .11
        mov bx,0x0800
        call random
        mov bx,items
        jmp .12
.11:
        mov bx,0x0400
        call random
        add al,[level]
.10:
        cmp al,0x1b
        jb .9
        sub al,0x05
        jmp .10
.9:
        mov bx,monsters-1
.12:
        cs xlat
        pop bx
        mov byte [bx+di],al
.8:
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

ladder_found:
        mov al,[level]
        add al,[yendor]
        je .1           ; Jump if reached level zero
        jmp generate_dungeon

        ; Success! The light of day
.1:     mov ax,0x0f0f
        call cls
quit:   mov ah,0x00
        int 0x16
        int 0x20
cls:
        xor di,di
        mov cx,0x07d0
        rep stosw
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
        cbw
add_hp: add ax,[hp]
        cmp ax,[max_hp]
        jl .2
        mov ax,[max_hp]
.2:     mov [hp],ax
        test ax,ax
        js .1
        ret
.1:        
        mov ax,0x0c0f
        call cls
        jmp quit

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
.1:
        ; Player's attack
.2:
        push ax
        mov bh,[weapon]
        mov bl,0x01
        call random
        cbw
        pop bx
        sub bx,ax
        jc .3
        ; Monster's attack
        push bx
        mov bh,[monster]
        mov bl,1
        call random
        sub al,[armor]
        jnc .4
        xor al,al
.4:
        cbw
        neg ax
        call add_hp
        call update_hp
        mov ah,0x00
        int 0x16
        pop ax
        jmp .2

        ; Monster is dead
.3:
        pop bx
        lea di,[di+bx]
        mov byte [di],GR_FLOOR
        mov al,[monster]
        cbw
        inc ax
        add ax,[exp]
        cmp ax,[n_exp]
        jb .5
        shl word [n_exp],1
        shl word [max_hp],1
.5:     mov [exp],ax
        ret

update_hp:
        push di
        mov di,0x0f9c
        mov ax,[max_hp]
        call show_number
        mov ax,0x0a2f
        std
        stosw
        cld
        mov ax,[hp]
        call show_number
        mov ax,0x0a20
        std
        stosw
        cld
        pop di
        ret

show_number:
        xor dx,dx
        mov cx,10
        div cx
        xchg ax,dx
        add al,0x30
        mov ah,0x0a
        std
        stosw
        cld
        xchg ax,dx
        or ax,ax
        jnz show_number
        ret

        ;
        ; Fill a row with 3 rooms
        ;
fill_row:
	add di,ROW_WIDTH*7+4
	call fill_column
	call fill_column
        ; Fall thru for another fill_column call
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
        rep stosw       ; Horizontal path
        pop di
.3:     
        je .5
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
        mov bx,0x0301
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

ladder_positions:
        dw 3*ROW_WIDTH+12*2
        dw 3*ROW_WIDTH+64*2
        dw 19*ROW_WIDTH+12*2
        dw 19*ROW_WIDTH+64*2

dirs:   db -81,-80,-79,0,
        db -1,0,1,0
        db 79,80,81

    %ifdef com_file
    %else
        times 510-($-$$) db 0x4f
        db 0x55,0xaa            ; Make it a bootable sector
    %endif

