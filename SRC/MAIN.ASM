segment data
        bg_sprite:
        incbin  "..\IMAGES\BG.BMP", 54 + 1024   ; Skips 54 byts from header
                                                ; and 1kB for color info
                                                ; we only need thge raw bytes                                              
        prev_mode:      RESB    1

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
;-- FUNCTIONS ----------------------------------------------------------------
; show_bg function:
;       shows the background on the screen
; USAGE:
;       PUSH    bg_addr         (pointer to bg buffer)
;       CALL    show_bg
;
; RESTRICITIONS:
;       - none
show_bg:
        ; Saving context
        PUSH    BP
        MOV     BP, SP
        PUSHF
        PUSH    AX
        PUSH    ES
        PUSH    SI
        PUSH    DI
        PUSH    CX

        ; Seting ES for video memory address
        MOV     AX, 0A000H
        MOV     ES, AX

        MOV     SI, [BP + 4]    ; Get source buffer address from the stack
        MOV     DI, 64000 - 320 ; Start from the last row beacuse the bmp
                                ; format stores the image upside down
        CLD
        MOV     CX, 200
        show_bg_l1:
                PUSH    CX
                MOV     CX, 320
                REP     MOVSB
                SUB     DI, 320 * 2
                POP     CX
        LOOP    show_bg_l1

        ; Retrieving context
        POP     CX
        POP     DI
        POP     SI
        POP     ES
        POP     AX
        POPF
        POP     BP
        RET     2
;-----------------------------------------------------------------------------
segment stack stack
        resb 256
stacktop:
