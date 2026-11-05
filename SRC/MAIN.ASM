EXTERN  load_sprite, show_bg    ; from SPRITE.ASM

segment data
        bg_filename:    DB      "..\IMAGES\BG.BMP", 0
        bg_sprite:      RESB    64000
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
;-----------------------------------------------------------------------------
        PUSH    WORD bg_sprite
        CALL    show_bg
        MOV     AH, 08H      
        INT     21H

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
