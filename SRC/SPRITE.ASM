;=============================================================================
; SPRITE.ASM
;       Graphics routines for VGA mode 13h (320x200, 256 colors, 1 byte per
;       pixel): sprite loading from BMP, background and sprite
;       drawing, and the back buffer -> VRAM copy.
;       Colors are raw palette indices (the BMP palette is not loaded), and
;       index 0 is treated as transparent when drawing sprites.
;=============================================================================

GLOBAL  load_sprite, show_bg, show_sprite, flip_screen

segment data
        transparent:    EQU     0       ; Palette index skipped by show_sprite
        file_handler:   DW      0       ; DOS handle of the BMP being read
        file_offset:    TIMES 4 DB 0    ; 32-bit offset of the pixel data (BMP header)

segment code
;-- show_bg function ---------------------------------------------------------
;       shows the background on the screen or buffer
;       Copies a full 320x200 image (64000 bytes) with no transparency
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
        MOV     CX, 32000       ; 320 * 200 = 64000 bytes = 32000 words
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
;       Draws a width x height sprite with its top-left corner at (x, y).
;       Pixels equal to 'transparent' are skipped, leaving whatever is already
;       in the destination.
; RESTRICTIONS:
;       - no clipping: the sprite must lie entirely inside the 320x200 area,
;         otherwise it wraps around or writes outside the buffer
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

        ; Source: DS:SI = sprite buffer
        MOV     AX, [BP + 14]   ; sprite_segment
        MOV     DS, AX
        MOV     SI, [BP + 12]   ; sprite_buffer 

        CLD                     

        ; Outer loop: one iteration per row / inner loop: one per pixel
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

                ; End of row: DI already advanced 'width' pixels, so skip the
                ; remaining (320 - width) to reach the start of the next row
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
;       The buffer must hold a full frame (64000 bytes).
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
        ; Bit 3 of the VGA status register (3DAh) is 1 while the vertical
        ; retrace is in progress. Waiting for the end of any retrace in
        ; progress and then for the start of the next one makes the copy start
        ; exactly at the beginning of a retrace, avoiding tearing.
        MOV     DX, 03DAh
wait_retrace_end:
        IN      AL, DX
        TEST    AL, 8
        JNZ     wait_retrace_end
wait_retrace_start:
        IN      AL, DX
        TEST    AL, 8
        JZ      wait_retrace_start

        ; --- Transfer (64000 bytes copied as 32000 words) ---
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
;       Expects an 8-bit (256 colors) BMP: one byte per pixel, which is what
;       the VGA mode 13h buffers use. The BMP palette is ignored.
; USAGE:
;       PUSH    file_name       (pointer to the string file name)
;       PUSH    buffer_segment
;       PUSH    buffer          (pointer to the buffer to store raw the bytes)
;       PUSH    width           (image width)
;       PUSH    height          (image height)
;       CALL    load_sprite
;
; RESTRICTIONS:
;       - the buffer size must be enough to store width * height bytes
;       - width must be a multiple of 4: BMP pads each row to a 4-byte
;         boundary and this routine reads exactly 'width' bytes per row
;       - errors are not handled yet (see the TODO below)
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

        ; Stack layout: [BP+12]=file_name  [BP+10]=buffer_segment  [BP+8]=buffer
        ;                [BP+6]=width       [BP+4]=height

        ; Opening the file
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
        MOV     DX, 0AH         ; Offset 0Ah of the BMP header = where the pixel data starts
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
        MOV     CX, [file_offset + 2]   ; High word of the offset
        INT     21H
        JC      pointer_move_err

        ; Reading the sprite. BMP stores its rows bottom-up, so the first row
        ; in the file is the LAST row of the buffer: DI starts there and goes
        ; up one row at a time.

        ; Initializing the dst (last row of the buffer): buffer + (height - 1) * width
        MOV     AX, [BP + 4]            ; sprite height
        DEC     AX                      ; AX = height - 1
        MOV     CX, [BP + 6]            ; sprite width
        MUL     CX
        ADD     AX, [BP + 8]            ; buffer addr
        MOV     DI, AX                  ; dst index: buffers last row

        ; Reading the file line by line
        MOV     CX, [BP + 4]           ; Number of rows
        MOV     BX, [file_handler]     ; to avoid problems with DS changes

        ; DOS read (AH=3Fh) writes to DS:DX, so DS must point to the buffer
        ; segment while reading (the file handle was already copied to BX)
        PUSH    DS
        MOV     AX, [BP + 10]
        MOV     DS, AX
        load_sprite_l1:
                PUSH    CX
                MOV     AH, 3FH                 ; Read file (row by row)
                MOV     CX, [BP + 6]            ; Sprite width (row size)
                MOV     DX, DI                  ; DS:DX = this row in the buffer
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
        ; TODO: handle errors (for now every error just jumps to the exit)

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