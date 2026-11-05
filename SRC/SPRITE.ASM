GLOBAL  load_sprite, show_bg

segment data
        file_handler:   DW      0
        file_offset:    TIMES 4 DB 0

segment code
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
        XOR     DI, DI          ; DI = 0

        CLD
        MOV     CX, 64000       ; Screen size
        REP     MOVSB

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
        PUSH    CX
        PUSH    DI

        ; Openning the file
        MOV     AH, 3DH         ; Open file DOS function
        MOV     AL, 00H         ; Read Only mode
        MOV     DX, [BP + 10]   ; File name (1st stack parameter)
        INT     21H
        JC      open_file_err   ; The carry flag is set if error
        MOV     [file_handler], AX

        ; Reading the offset of the pixel data (as in the bmp header format)
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
        MOV     AH, 42H                 ; Move file pointer
        MOV     AL, 00H                 ; Move from the start of the file
        MOV     BX, [file_handler]
        MOV     DX, [file_offset]       ; Low word of the offset
        MOV     CX, [file_offset + 2]   ; Hight word of the offset
        INT     21H
        JC      pointer_move_err

        ; Reading the sprite (from bottom to top beacuse of the bmp format)
        ; bmp stores on the inverted order

        ; Initializing the dst (last row of the buffer)
        MOV     AX, [BP + 4]            ; sprite height
        DEC     AX                      ; AX = height - 1
        MOV     CX, [BP + 6]            ; sprite width
        MUL     CX
        ADD     AX, [BP + 8]            ; buffer addr
        MOV     DI, AX                  ; dst index: buffers last row

        ; Reading the file line by line
        MOV     CX, [BP + 4]           ; Number of rows
        load_sprite_l1:
                PUSH    CX
                MOV     AH, 3FH
                MOV     BX, [file_handler]
                MOV     CX, [BP + 6]            ; Sprite width (row size)
                MOV     DX, DI
                INT     21H
                JC      read_file_err

                SUB     DI, [BP + 6]            ; Go up one line

                POP CX
        LOOP    load_sprite_l1


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
        POP     CX
        POP     BX
        POP     DX
        POP     AX
        POPF
        POP     BP
        RET     8       ; 4 stack parameters
;-----------------------------------------------------------------------------

