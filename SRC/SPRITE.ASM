GLOBAL  load_sprite, show_bg, show_sprite

segment data
        transparent:    EQU     0
        file_handler:   DW      0
        file_offset:    TIMES 4 DB 0

segment code
;-- show_bg function ---------------------------------------------------------
;       shows the background on the screen
; USAGE:
;       PUSH    bg_segment      (new DS)
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
        PUSH    DS
        PUSH    ES
        PUSH    SI
        PUSH    DI
        PUSH    CX

        ; Seting ES for video memory address
        MOV     AX, 0A000H
        MOV     ES, AX

        MOV     AX, [BP + 6]    ; Buffer segment
        MOV     DS, AX
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
        POP     DS
        POP     AX
        POPF
        POP     BP
        RET     4       ; 2 stack parameters
;-----------------------------------------------------------------------------

;-- show_sprite function -----------------------------------------------------
;       shows a generic sprite in a given position on screen
; USAGE:
;       PUSH    sprite_segment  (buffer segment)
;       PUSH    sprite_addr     (pointer to sprite buffer)
;       PUSH    width
;       PUSH    height
;       PUSH    x
;       PUSH    y
;       CALL    show_sprite
;
; RESTRICITIONS:
;       - x >= 0
;       - x + width < 320
;       - y >= 0
;       - y + height < 200
show_sprite:
        ; Saving context
        PUSH    BP
        MOV     BP, SP
        PUSHF
        PUSH    AX
        PUSH    DS
        PUSH    ES
        PUSH    BX
        PUSH    CX
        PUSH    DX
        PUSH    DI
        PUSH    SI

        ; Seting ES for video memory address
        MOV     AX, 0A000H
        MOV     ES, AX

        ; Initial VRAM offset: DI = (y * 320) + x
        MOV     AX, [BP + 4]    ; y coord
        MOV     BX, 320
        MUL     BX
        ADD     AX, [BP + 6]    ; DX:AX = (x * 320) + x (will never overflow AX)
        MOV     DI, AX          ; DI = (x, y) on the video memory

        ; Setting SI
        MOV     AX, [BP + 14]   ; buffer segment
        MOV     DS, AX
        MOV     SI, [BP + 12]   ; sprite address

        CLD                     ; left to ritgh (SI/DI operations)

        MOV     CX, [BP + 8]    ; height, rows count
        show_sprite_l1:
                PUSH    CX

                MOV     CX, [BP + 10]   ; width
                show_sprite_l2:
                        LODSB                   ; AL = [DS:SI] and SI = SI + 1
                        CMP     AL, transparent
                        JE      skip_pixel
                        MOV     [ES:DI], AL     ; Draw pixel if its not transparent

                        skip_pixel:
                        INC     DI              ; Next pixel on screen
                LOOP    show_sprite_l2

                ; Go to the next row
                MOV     AX, 320
                SUB     AX, [BP + 10]   ; AX = 320 - width
                ADD     DI, AX          ; Moves DI to the next row

                POP     CX
        LOOP    show_sprite_l1
                                   
        ; Retrieving context
        POP     SI
        POP     DI
        POP     DX
        POP     CX
        POP     BX
        POP     ES
        POP     DS
        POP     AX
        POPF
        POP     BP
        RET     12       ; 6 stack parameter
;-----------------------------------------------------------------------------

;-- load_sprite function -----------------------------------------------------
;       load a sprite (in bmp format) from disk to memory converting it into
;       a raw buffer (on the correct order)
; USAGE:
;       PUSH    file_name       (pointer to the string file name)
;       PUSH    buffer_segment
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
        PUSH    DS

        ; Openning the file
        MOV     AH, 3DH         ; Open file DOS function
        MOV     AL, 00H         ; Read Only mode
        MOV     DX, [BP + 12]   ; File name (1st stack parameter)
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
        MOV     BX, [file_handler]     ; to avoid problems with DS changes

        PUSH    DS
        MOV     AX, [BP + 10]
        MOV     DS, AX
        load_sprite_l1:
                PUSH    CX
                MOV     AH, 3FH                 ; Read file (row by row)
                MOV     CX, [BP + 6]            ; Sprite width (row size)
                MOV     DX, DI
                INT     21H
                JC      read_file_err

                SUB     DI, [BP + 6]            ; Go up one line

                POP CX
        LOOP    load_sprite_l1
        POP     DS


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
        POP     DS
        POP     DI
        POP     CX
        POP     BX
        POP     DX
        POP     AX
        POPF
        POP     BP
        RET     10       ; 5 stack parameters
;-----------------------------------------------------------------------------

