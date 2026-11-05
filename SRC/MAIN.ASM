segment data
        bg_filename:    DB      "..\IMAGES\BG.BMP", 0
        bg_sprite:      RESB    64000
        prev_mode:      DB      0
        file_handler:   DW      0
        file_offset:    TIMES 4 DB 0

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
        PUSH    WORD bg_filename
        PUSH    WORD bg_sprite
        PUSH    WORD 320
        PUSH    WORD 200
        CALL    load_sprite

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
        RET     2       ; 1 stack parameter

; load_sprite function:
;       load a sprite (in bmp format) from disk to memory converting it into
;       a raw buffer (on the correct order)
; USAGE:
;       PUSH    file_name       (pointer to the string file name)
;       PUSH    buffer          (pointer to the buffer to store raw the bytes)
;       PUSH    width           (image width)
;       PUSH    height          (image height)
;       CALL    load_sprite
;
; RESTRICITIONS:
;       - the buffer size must be enough to store width * height bytes
load_sprite:
        ; Saving context
        PUSH    BP
        MOV     BP, SP
        PUSHF
        PUSH    AX
        PUSH    DX
        PUSH    BX
        PUSH    DX
        PUSH    DI

        ; Openning the file
        MOV     AH, 3DH         ; Open file DOS function
        MOV     AL, 00H         ; Read Only mode
        MOV     DX, [BP + 10]   ; File name (1st stack parameter)
        INT     21H
        JC      open_file_err   ; The carry flag is set if error
        MOV     [file_handler], AX

        ; Reading the offset of the raw bytes (as in the bmp header format)
        MOV     AH, 42H         ; Move file pointer
        MOV     AL, 00H         ; Move from the start of the file
        MOV     BX, [file_handler]
        XOR     CX, CX
        MOV     DX, 0AH         ; See the bmp header format for reference
        INT     21H
        JC      pointer_move_err

        MOV     AH, 3FH
        MOV     BX, [file_handler]
        MOV     CX, 4           ; the raw data offset is stored in 4 bytes
        MOV     DX, file_offset
        INT     21H
        JC      read_file_err

        ; Moving the file pointer to the actual raw data (pixel data) offset
        MOV     AH, 42H         ; Move file pointer
        MOV     AL, 00H         ; Move from the start of the file
        MOV     BX, [file_handler]
        MOV     DX, [file_offset]       ; Low word of the offset
        MOV     CX, [file_offset + 2]   ; Hight word of the offset
        INT     21H
        JC      pointer_move_err

        MOV     AH, 3FH
        MOV     BX, [file_handler]
        MOV     CX, 64000
        MOV     DX, bg_sprite
        INT     21H
        JC      read_file_err

        ; Closing the file
        MOV     AH, 3EH
        MOV     BX, [file_handler]
        INT     21H
        JC      close_file_err

        JMP     load_sprite_exit        ; Normal exit

        open_file_err:
        pointer_move_err:
        read_file_err:
        close_file_err:
        ; TODO: handle errors

        load_sprite_exit:
        ; Retreiving context
        POP     DI
        POP     DX
        POP     BX
        POP     DX
        POP     AX
        POPF
        POP     BP
        RET     8       ; 4 stack parameters



;-----------------------------------------------------------------------------
segment stack stack
        resb 256
stacktop:
