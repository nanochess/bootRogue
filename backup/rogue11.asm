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
        ;                             works. Added battles. 829 bytes.
        ; Revision date: Sep/23/2019. Lots of optimization. 643 bytes.
        ; Revision date: Sep/24/2019. Again lots of optimization. 596 bytes.
        ; Revision date: Sep/25/2019. Many optimizations. 553 bytes.
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
        in ax,0x40      ; Read timer counter
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
        ;
        ; Advance to next level (can go deeper or higher)
        ;
        mov al,[bp+yendor]
        add [bp+level],al
        je $            ; Stop if level zero is reached

        ;
        ; Select a maze for the dungeon
        ;
        mov ax,[bp+rnd]        
        and ax,0x4182
        or ax,0x1a6d
        xchg ax,si

        ;
        ; Clean the screen
        ;
        xor ax,ax
        xor di,di
        mov ch,0x08
        rep stosw

        ;
        ; Draw the nine rooms
        ;
        mov ax,(BOX_HEIGHT/2-2)*ROW_WIDTH+(BOX_WIDTH/2-2)*2
.4:
        push ax
        call fill_room
        pop ax
        add ax,BOX_WIDTH*2
        cmp al,0xf2             ; Finished drawing three rooms?
        jne .5                  ; No, jump
                                ; Yes, go to following row
        add ax,ROW_WIDTH*BOX_HEIGHT-BOX_WIDTH*3*2
.5:
        cmp ax,ROW_WIDTH*BOX_HEIGHT*3
        jb .4

        ;
        ; Put the ladder at a random corner room
        ;
        shl word [bp+rnd],1
        mov ax,3*ROW_WIDTH+12*2       
        mov bx,19*ROW_WIDTH+12*2        
        jnc .2
        xchg ax,bx
.2:     jns .3
        add ax,BOX_WIDTH*2*2
.3:
        xchg ax,di
        mov byte [di],GR_LADDER

        ;
        ; If a deep level has been reached then put the Amulet of Yendor
        ;
        cmp byte [bp+level],YENDOR_LEVEL
        jb .1
        mov byte [bx],GR_YENDOR
.1:
        ;
        ; Setup hero start
        ;
        mov di,11*ROW_WIDTH+38*2
        ;
        ; Main game loop
        ;
game_loop:
        mov ax,game_loop        ; Force to repeat, the whole loop...
        push ax                 ; ...ends with ret.

        ;
        ; Circle of light around the player (3x3)
        ;
        mov bx,0x0005                   ; BX values
.1:     dec bx
        dec bx                          ; -1 1 3 -0x00a0
        mov al,LIGHT_COLOR     
        mov [bx+di-ROW_WIDTH],al        ; -1(1)3 
        mov [bx+di],al                      
        mov [bx+di+ROW_WIDTH],al        ; -1 1 3 +0x00a0
        jns .1

        ;
        ; Show our hero
        ;
        push word [di]          ; Save character under 
        mov word [di],HERO_COLOR*256+GR_HERO
        xor ax,ax
        call add_hp             ; Update stats
    ;   mov ah,0x00             ; Comes here with ah = 0
        int 0x16                ; Read keyboard
        pop word [di]           ; Restore character under 

        mov al,ah

        sub al,0x4c
        mov ah,0x02             ; Left/right multiplies by 2
        cmp al,0xff             ; Going left (scancode 0x4b)
        je .2
        cmp al,0x01             ; Going right (scancode 0x4d)
        je .2
        cmp al,0xfc             ; Going up (scancode 0x48)
        je .3
        cmp al,0x04             ; Going down (scancode 0x50)
        jne move_cancel
.3:
        mov ah,0x28             ; Up/down multiplies by 40
.2:
        imul ah                 ; Signed multiplication

        xchg ax,bx              ; bx = displacement offset
        mov al,[di+bx]          ; Read the target contents
        cmp al,GR_LADDER        ; GR_LADDER?
        je ladder_found         ; Yes, jump to next level
        ja move_over            ; > it must be GR_FLOOR
        cmp al,GR_DOOR          ; GR_DOOR?
        je move_over            ; Yes, can move
        cmp al,GR_TUNNEL        ; GR_TUNNEL?
        je move_over            ; Yes, can move
        ja move_cancel          ; > it must be border, cancel movement
        cmp al,GR_TRAP          ; GR_TRAP?
        jb move_cancel          ; < it must be blank, cancel movement
        lea di,[di+bx]          ; Do move.
        je trap_found           ; = Yes, went over trap
        cmp al,GR_WEAPON        ; GR_WEAPON?
        ja battle               ; > it's a monster, go to battle
        mov byte [di],GR_FLOOR  ; Delete item from floor
        je weapon_found         ; = weapon found
        cmp al,GR_ARMOR         ; GR_ARMOR?
        je armor_found          ; Yes, increase armor
        jb food_found           ; < it's GR_FOOD, increase hp
        cmp al,GR_GOLD          ; GR_GOLD?
        je move_cancel          ; Yes, simply take it.
        ; At this point 'al' only can be GR_YENDOR
        ; Amulet of Yendor found!
        neg byte [bp+yendor]    ; Now player goes upwards over ladders.
        ret
move_over:        
        lea di,[bx+di]          ; Do move.
move_cancel:
        ret                     ; Return to main loop.

        ;
        ;     I--
        ;   I--
        ; I--
        ;
ladder_found:
        jmp generate_dungeon

        ; ----
        ; I  I
        ;  \/
armor_found:
        inc byte [bp+armor]     ; Increase armor level
        ret

        ;   A
        ; ==I=======
        ;   V
weapon_found:
        inc byte [bp+weapon]    ; Increase weapon level
        ret

        ;     /--\
        ; ====    I
        ;     \--/
food_found:
        call random6            ; Random 1-6
        jmp add_hp

        ;
        ; Aaaarghhhh!
        ;
trap_found:
        call random6            ; Random 1-6
sub_hp: neg ax                  ; Make it negative
add_hp: add ax,[bp+hp]          ; Add to current HP
        js $                    ; Stall if dead
        cmp ax,[bp+max_hp]      ; Exceeds maximum possible HP?
        jl .1                   ; No, jump
        mov ax,[bp+max_hp]      ; Limit it.
.1:     mov [bp+hp],ax          ; Update HP.
        ;
        ; Update screen indicator
        ;
        mov bx,0x0f9c
        call show_number
        mov ax,[bp+max_hp]
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

        ;
        ; Let's battle!!!
        ;
battle:
        and al,0x1f     ; Separate number of monster (1-26)     
        cbw             ; Extend to 16 bits
        mov bl,al       ; It's attack is equivalent to its number
        xchg ax,si      ; Use also as its HP
        ; Player's attack
.2:
        mov bh,[bp+weapon]      ; Use current weapon level as dice
        call random
        sub si,ax       ; Subtract from monster's HP
        mov bh,bl
        jc .3           ; Killed? yes, jump
        ; Monster's attack
        call random     ; Use monster number as dice
        sub al,[bp+armor]       ; Subtract armor from attack                               
        jc .4
        push bx
        call sub_hp     ; Subtract from player's HP
        pop bx
.4:
    ;   mov ah,0x00     ; Comes here with ah = 0
        int 0x16        ; Wait for a key.
        jmp .2          ; Another battle round.

        ; Monster is dead
.3:
        mov byte [di],GR_FLOOR  ; Remove from screen
        call random             ; Use monster number as dice
        add ax,[bp+exp]         ; Add to exp
        cmp ax,[bp+n_exp]       ; Reached next level of exp?
        jb .5
        shl word [bp+n_exp],1   ; Double next level of exp
        shl word [bp+max_hp],1  ; Double current Max HP
.5:     mov [bp+exp],ax
        ret

        ;
        ; Fill a room
        ;
fill_room:
        push ax
        add ax,ROW_WIDTH+4
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
        mov bh,BOX_MAX_WIDTH-2
        call random
        xchg ax,cx
        mov bh,BOX_MAX_HEIGHT-2
        call random
        mov ch,al
        and al,0xfe
        mov bx,0x00fe
        and bx,cx
        mov ah,ROW_WIDTH/2
        mul ah
        add bx,ax
        pop ax
        sub ax,bx
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
        push ax
        xchg ax,di
	mov al,dh
        call door
.1:     mov al,bh
        call door
        dec cl
        jns .1
        mov al,bl
        call door
        pop ax
	pop cx
        add ax,0x00a0
	ret

door:
        cmp al,GR_FLOOR
        jne .3
        push bx
        mov bh,0x80
        call random
        cmp al,5                ; Chance of creating a item (1-4)
        jnc .11
        add al,[bp+level]
.9:
        sub al,0x05
        cmp al,0x16
        jge .9
        add al,0x45             ; Offset into ASCII letters
        jmp .12

.11:
        mov bx,items-5
        cmp al,10               ; 7% chance of creating a monster/item
        cs xlat
        jb .12
        mov al,GR_FLOOR
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
        db GR_TRAP
        db GR_WEAPON
        db GR_ARMOR

    %ifdef com_file
    %else
        times 510-($-$$) db 0x4f
        db 0x55,0xaa            ; Make it a bootable sector
    %endif

