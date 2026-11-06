EXTERN  load_sprite, show_bg, show_sprite       ; from SPRITE.ASM

segment data
        bg_filename:    DB      "..\IMAGES\BG.BMP", 0
        p1life_filename:DB      "..\IMAGES\P1LIFE.BMP", 0
        p2life_filename:DB      "..\IMAGES\P2LIFE.BMP", 0
        p1_filename:    DB      "..\IMAGES\P1.BMP", 0
        p2_filename:    DB      "..\IMAGES\P2.BMP", 0

        bg_sprite:      RESB    64000
        p1_sprite:      RESB    4096
        p2_sprite:      RESB    4096
        p1life_sprite:  RESB    64
        p2life_sprite:  RESB    64

        prev_mode:      DB      0

segment code
..start:
;-- INITIALIZING SEGMENTS ----------------------------------------------------
        MOV     AX, data
        MOV     DS, AX
        MOV     AX, stack
        MOV     SS, AX
        MOV     SP, stacktop
;-----------------------------------------------------------------------------

;-- SETTING SCREEN MODE (VGA) ------------------------------------------------
        ; Save current mode
        MOV     AH, 0FH
        INT     10H
        MOV     [prev_mode], AL
        ; Set mode to 320x200 256 colors vga (13H)
        MOV     AL, 13H
        MOV     AH, 00H
        INT     10H
;-----------------------------------------------------------------------------

;-- LOADING SPRITES ----------------------------------------------------------
        PUSH    WORD bg_filename
        PUSH    WORD bg_sprite
        PUSH    WORD 320
        PUSH    WORD 200
        CALL    load_sprite

        PUSH    WORD p1_filename
        PUSH    WORD p1_sprite
        PUSH    WORD 64
        PUSH    WORD 64
        CALL    load_sprite

        PUSH    WORD p1_filename
        PUSH    WORD p1_sprite
        PUSH    WORD 64
        PUSH    WORD 64
        CALL    load_sprite

        PUSH    WORD p1life_filename
        PUSH    WORD p1life_sprite
        PUSH    WORD 8
        PUSH    WORD 8
        CALL    load_sprite

        PUSH    WORD p2life_filename
        PUSH    WORD p2life_sprite
        PUSH    WORD 8
        PUSH    WORD 8
        CALL    load_sprite
;-----------------------------------------------------------------------------

;-- DRAWING ------------------------------------------------------------------
        PUSH    WORD bg_sprite
        CALL    show_bg

        PUSH    WORD p1life_sprite
        PUSH    WORD 8
        PUSH    WORD 8
        PUSH    WORD 0
        PUSH    WORD 0
        CALL    show_sprite

        MOV     AH, 08H
        INT     21H
;-----------------------------------------------------------------------------

;-- GRACEFUL EXIT ------------------------------------------------------------
        ; Set video mode back
        MOV     AL, [prev_mode]
        MOV     AH, 00H
        INT     10H

        MOV     AH, 4CH
        MOV     AL, 00H         ; Error code (no error)
        INT     21H
;-----------------------------------------------------------------------------

segment stack stack
        resb 256
stacktop:
