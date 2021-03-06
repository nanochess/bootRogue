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
        ; Revision date: Sep/24/2019. Again lots of optimization. 581 bytes.
        ;

        CPU 8086

ROW_WIDTH:      EQU 0x00A0      ; Width in bytes of each video row
BOX_MAX_WIDTH:  EQU 23          ; Max width of a room box
BOX_MAX_HEIGHT: EQU 6           ; Max height of a room box
BOX_WIDTH:      EQU 26          ; Width of box area in screen
BOX_HEIGHT:     EQU 8           ; Height of box area in screen

        ; See page 45 of my book
LIGHT_COLOR:    EQU 0x06        ; Light color (brown, dark yellow on emu)        
HERO_COLOR:     EQU 0x0e        ; Hero color (yellow)

        ; See page 179 of my book
GR_VERT:        EQU 0xba        ; Vertical line graphic
GR_TOP_RIGHT:   EQU 0xbb        ; Top right graphic
GR_BOT_RIGHT:   EQU 0xbc        ; Bottom right graphic
GR_BOT_LEFT:    EQU 0xc8        ; Bottom left graphic
GR_TOP_LEFT:    EQU 0xc9        ; Top left graphic
GR_HORIZ:       EQU 0xcd        ; Horizontal line graphic

GR_TUNNEL:      EQU 0xb1        ; Tunnel graphic (shaded block)
GR_DOOR:        EQU 0xce        ; Door graphic (crosshair graphic)
GR_FLOOR:       EQU 0xfa        ; Floor graphic (middle point)

GR_HERO:        EQU 0x01        ; Hero graphic (smiling face)

GR_LADDER:      EQU 0xf0        ; Ladder graphic 
GR_TRAP:        EQU 0x04        ; Trap graphic (diamond)
GR_FOOD:        EQU 0x05        ; Food graphic (clover)
GR_ARMOR:       EQU 0x08        ; Armor graphic (square with hole in center)
GR_YENDOR:      EQU 0x0c        ; Amulet of Yendor graphic (Female sign)
GR_GOLD:        EQU 0x0f        ; Gold graphic (asterisk, like brightness)
GR_WEAPON:      EQU 0x18        ; Weapon graphic (up arrow)

YENDOR_LEVEL:   EQU 26          ; Level of appearance for Amulet of Yendor

    %ifdef com_file
        org 0x0100
    %else
        org 0x7c00
    %endif

        ;
        ; Sorted by order of PUSH instructions
        ;
rnd:    equ 0x000c      ; Random seed
exp:    equ 0x000a      ; Current Exp
level:  equ 0x0009      ; Current level (starting at 0x01)
yendor: equ 0x0008      ; 0x01 = Not found. 0xff = Found.
armor:  equ 0x0007      ; Armor level
weapon: equ 0x0006      ; Weapon level
n_exp:  equ 0x0004      ; Level to next Exp
hp:     equ 0x0002      ; Current HP
max_hp: equ 0x0000      ; Max HP

        ;
        ; Start of the adventure!
        ;
start:
        in al,0x40      ; Read timer counter
        push ax         ; Setup pseudorandom number generator

        xor ax,ax
        push ax         ; exp
        inc ax
        push ax         ; yendor (low byte) + level (high byte)
        push ax         ; weapon (low byte) + armor (high byte)
        mov al,16
        push ax         ; n_exp
        push ax         ; hp
        push ax         ; max_hp
        mov al,0x02     ; ah already is zero
	int 0x10
        mov ax,0xb800   ; Text video segment
	mov ds,ax
        mov es,ax

        mov bp,sp
generate_dungeon:
        mov al,[bp+yendor]
        add [bp+level],al
        je $            ; Stop if level zero is reached

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

        shl word [bp+rnd],1
        mov bx,3*ROW_WIDTH+12*2       
        mov di,19*ROW_WIDTH+12*2        
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

        ;
        ; Circle of light around the player (3x3)
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
        call update_hp        
    ;   mov ah,0x00     ; Comes here with ah = 0
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
        jne move_cancel
.3:
        mov ah,0x28
.2:
        imul ah
        xchg ax,bx
        mov al,[di+bx]
        cmp al,GR_LADDER
        ja move_over            ; GR_FLOOR
        je ladder_found
        cmp al,GR_DOOR
        je move_over
        cmp al,GR_TUNNEL
        je move_over
        ja move_cancel
        cmp al,GR_TRAP
        jb move_cancel
        lea di,[di+bx]
        je trap_found
        cmp al,GR_WEAPON
        ja battle
        mov byte [di],GR_FLOOR
        je weapon_found
        cmp al,GR_ARMOR
        je armor_found
        jb food_found           ; GR_FOOD
        cmp al,GR_GOLD
        je move_cancel
        jb amulet_found         ; GR_YENDOR
move_over:        
        lea di,[bx+di]
move_cancel:
        ret

ladder_found:
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
        cwd             ; !!! Test our hp doesn't exceed 32767
        mov cx,10
        div cx
        add dx,0x0a30
        mov [bx],dx
        dec bx
        dec bx
        or ax,ax
        jnz show_number
.1:
        mov [bx],ax
        dec bx
        dec bx
        ret

battle:
        and al,0x1f
        cbw
        mov bl,al
        xchg ax,si
        ; Player's attack
.2:
        mov bh,[bp+weapon]
        call random
        sub si,ax
        mov bh,bl
        jc .3
        ; Monster's attack
        call random
        sub al,[bp+armor]
        jc .4
        push bx
        call sub_hp
        pop bx
.4:
    ;   mov ah,0x00     ; Comes here with ah = 0
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

