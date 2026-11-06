GLOBAL  load_sprite, show_bg, show_sprite, flip_screen

segment data
        transparent:    EQU     0
        file_handler:   DW      0
        file_offset:    TIMES 4 DB 0

segment code
;-- show_bg function ---------------------------------------------------------
;       shows the background on the screen or buffer
; USAGE:
;       PUSH    dest_segment    (tmp buffer or screen)
;       PUSH    bg_segment      (new DS)
;       PUSH    bg_addr         (pointer to bg buffer)
;       CALL    show_bg
show_bg:
        PUSH    BP
        MOV     BP, SP
        PUSHF
        PUSH    AX
        PUSH    DS
        PUSH    ES
        PUSH    SI
        PUSH    DI
        PUSH    CX

        MOV     AX, [BP + 8]    ; Dest segment
        MOV     ES, AX

        MOV     AX, [BP + 6]    ; Buffer segment
        MOV     DS, AX
        MOV     SI, [BP + 4]    ; Get source buffer address from the stack

        XOR     DI, DI          ; DI = 0
        CLD
        MOV     CX, 32000       ; Screen size em words
        REP     MOVSW           ; Faster than MOVSB

        POP     CX
        POP     DI
        POP     SI
        POP     ES
        POP     DS
        POP     AX
        POPF
        POP     BP
        RET     6       ; 3 stack parameters
;-----------------------------------------------------------------------------

;-- show_sprite function -----------------------------------------------------
; USAGE:
;       PUSH    dest_segment    (tmp buffer or screen)
;       PUSH    sprite_segment  (buffer segment)
;       PUSH    sprite_addr     (pointer to sprite buffer)
;       PUSH    width
;       PUSH    height
;       PUSH    x
;       PUSH    y
;       CALL    show_sprite
show_sprite:
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

        MOV     AX, [BP + 16]   ; dst segment
        MOV     ES, AX

        ; Initial Dest offset: DI = (y * 320) + x
        MOV     AX, [BP + 4]    ; y coord
        MOV     BX, 320
        MUL     BX
        ADD     AX, [BP + 6]    ; x
        MOV     DI, AX          

        ; Setting SI
        MOV     AX, [BP + 14]   ; dest_segment 
        MOV     DS, AX
        MOV     SI, [BP + 12]   ; sprite_buffer 

        CLD                     

        MOV     CX, [BP + 8]    ; height
        show_sprite_l1:
                PUSH    CX

                MOV     CX, [BP + 10]   ; width
                show_sprite_l2:
                        LODSB                   
                        CMP     AL, transparent
                        JE      skip_pixel
                        MOV     [ES:DI], AL     

                        skip_pixel:
                        INC     DI              
                LOOP    show_sprite_l2

                MOV     AX, 320
                SUB     AX, [BP + 10]   
                ADD     DI, AX          

                POP     CX
        LOOP    show_sprite_l1
                                   
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
        RET     14       ; 7 stack parameters
;-----------------------------------------------------------------------------

;-- flip_screen function -----------------------------------------------------
;       Waits for VGA vsync and copies the off-screen buffer to actual VRAM
; USAGE:
;       PUSH    buffer_segment
;       PUSH    buffer_offset
;       CALL    flip_screen
flip_screen:
        PUSH    BP
        MOV     BP, SP
        PUSHF
        PUSH    AX
        PUSH    CX
        PUSH    DX
        PUSH    SI
        PUSH    DI
        PUSH    DS
        PUSH    ES

        MOV     AX, 0A000H
        MOV     ES, AX                  ; dst: VRAM

        MOV     AX, [BP + 6]
        MOV     DS, AX
        MOV     SI, [BP + 4]            ; src: tmp buffer

        ; --- VSYNC ---
        MOV     DX, 03DAh
wait_retrace_end:
        IN      AL, DX
        TEST    AL, 8
        JNZ     wait_retrace_end
wait_retrace_start:
        IN      AL, DX
        TEST    AL, 8
        JZ      wait_retrace_start

        ; --- Transfer ---
        XOR     DI, DI
        MOV     CX, 32000
        CLD
        REP     MOVSW

        POP     ES
        POP     DS
        POP     DI
        POP     SI
        POP     DX
        POP     CX
        POP     AX
        POPF
        POP     BP
        RET     4
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

