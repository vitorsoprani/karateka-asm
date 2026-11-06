EXTERN load_sprite, show_bg, show_sprite, flip_screen
EXTERN set_clock_isr, set_key_isr, reset_clock_isr, reset_key_isr
EXTERN p1_w, p1_a, p1_s, p1_d, p1_r, p1_t
EXTERN p2_up, p2_left, p2_down, p2_right, p2_n, p2_m
EXTERN sys_p, sys_q, sys_render_frame
EXTERN p1_sprite, p2_sprite, p1life_sprite, p2life_sprite
EXTERN p1_x_vel, p1_y_vel, p2_x_vel, p2_y_vel
EXTERN move_p1, move_p2, draw_players

segment bg_data
        bg_sprite:      RESB    64000

segment double_buffer_data
        screen_buffer:  RESB    64000
        

segment data
        bg_filename:    DB      "..\IMAGES\BG.BMP", 0
        p1life_filename:DB      "..\IMAGES\P1LIFE.BMP", 0
        p2life_filename:DB      "..\IMAGES\P2LIFE.BMP", 0
        p1_filename:    DB      "..\IMAGES\P1.BMP", 0
        p2_filename:    DB      "..\IMAGES\P2.BMP", 0

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

;-- SETTING ISRS--------------------------------------------------------------
        CALL    set_clock_isr
        CALL    set_key_isr
;-----------------------------------------------------------------------------


;-- LOADING SPRITES ----------------------------------------------------------
        PUSH    WORD bg_filename
        PUSH    WORD bg_data
        PUSH    WORD bg_sprite
        PUSH    WORD 320
        PUSH    WORD 200
        CALL    load_sprite

        PUSH    WORD p1_filename
        PUSH    WORD data
        PUSH    WORD p1_sprite
        PUSH    WORD 64
        PUSH    WORD 64
        CALL    load_sprite

        PUSH    WORD p2_filename
        PUSH    WORD data
        PUSH    WORD p2_sprite
        PUSH    WORD 64
        PUSH    WORD 64
        CALL    load_sprite

        PUSH    WORD p1life_filename
        PUSH    WORD data
        PUSH    WORD p1life_sprite
        PUSH    WORD 8
        PUSH    WORD 8
        CALL    load_sprite

        PUSH    WORD p2life_filename
        PUSH    WORD data
        PUSH    WORD p2life_sprite
        PUSH    WORD 8
        PUSH    WORD 8
        CALL    load_sprite
;-----------------------------------------------------------------------------

;-- DRAWING ------------------------------------------------------------------
        main_loop:
        ; Framerate enforcing
        CMP     BYTE [sys_render_frame], 1
        JNE     check_quit
        MOV     BYTE [sys_render_frame], 0


        ; Player 1 input Processing
        MOV WORD [p1_x_vel], 0     ; Reset vel

        CMP BYTE [p1_a], 1         ; Left pressed?
        JNE check_p1_right
        MOV WORD [p1_x_vel], -5    ; Move left

        check_p1_right:
        CMP BYTE [p1_d], 1         ; Right pressed?
        JNE p2_input_processing
        MOV WORD [p1_x_vel], 5     ; Move right

        p2_input_processing:
        ; Player 2 input Processing
        MOV WORD [p2_x_vel], 0     ; Reset vel

        CMP BYTE [p2_left], 1         ; Left pressed?
        JNE check_p2_right
        MOV WORD [p2_x_vel], -5    ; Move left

        check_p2_right:
        CMP BYTE [p2_right], 1         ; Right pressed?
        JNE update_positions
        MOV WORD [p2_x_vel], 5     ; Move right

        update_positions:
        CALL move_p1
        CALL move_p2

        ; Rendering
        PUSH    WORD double_buffer_data
        PUSH    WORD bg_data
        PUSH    WORD bg_sprite
        CALL    show_bg
       
        PUSH WORD double_buffer_data
        CALL draw_players 

        ; Wrinting to video memory
        PUSH    WORD double_buffer_data
        PUSH    WORD screen_buffer
        CALL    flip_screen

        check_quit:
        CMP     BYTE [sys_q], 1
        JE      quit_main_loop
        JMP     main_loop

        quit_main_loop:
;-----------------------------------------------------------------------------

;-- GRACEFUL EXIT ------------------------------------------------------------
        ; Set video mode back
        MOV     AL, [prev_mode]
        MOV     AH, 00H
        INT     10H

        ; Reseting ISRs
        CALL    reset_clock_isr
        CALL    reset_key_isr

        MOV     AH, 4CH
        MOV     AL, 00H         ; Error code (no error)
        INT     21H
;-----------------------------------------------------------------------------

segment stack stack
        resb 256
stacktop:
