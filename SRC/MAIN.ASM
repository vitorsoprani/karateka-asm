;=============================================================================
; MAIN.ASM
;       Entry point and game loop.
;         - sets VGA mode 13h (320x200, 256 colors) and hooks the clock and
;           keyboard ISRs (ISRS.ASM)
;         - loads every BMP sprite into memory (SPRITE.ASM)
;         - runs the main loop once per clock tick:
;               input -> movement -> render (back buffer) -> flip to VRAM
;         - restores the video mode and the original ISRs before exiting
;=============================================================================

EXTERN load_sprite, show_bg, show_sprite, flip_screen
EXTERN set_clock_isr, set_key_isr, reset_clock_isr, reset_key_isr
EXTERN p1_w, p1_a, p1_s, p1_d, p1_r, p1_t
EXTERN p2_up, p2_left, p2_down, p2_right, p2_n, p2_m
EXTERN sys_p, sys_q, sys_render_frame
EXTERN p1_sprite, p2_sprite, p1life_sprite, p2life_sprite
EXTERN p1_x_vel, p1_y_vel, p2_x_vel, p2_y_vel
EXTERN move_p1, move_p2, draw_players
EXTERN p1_punch, p2_punch, p1_kick, p2_kick, update_attacks
EXTERN p1punch_sprite, p2punch_sprite, p1kick_sprite, p2kick_sprite

; The 320x200 buffers (64000 bytes each) get their own segments so that the
; 'data' segment (sprites, key flags and variables) stays within 64 KB.
segment bg_data
        bg_sprite:      RESB    64000   ; Background image (BG.BMP)

segment double_buffer_data
        ; Back buffer: every frame is composed here and then copied to VRAM by
        ; flip_screen. Callers use the SEGMENT (double_buffer_data) as the
        ; destination and 'screen_buffer' as the offset inside it.
        screen_buffer:  RESB    64000
        

segment data
        ; Sprite files (null-terminated for DOS INT 21h).
        bg_filename:    DB      "..\IMAGES\BG.BMP", 0
        p1life_filename:DB      "..\IMAGES\P1LIFE.BMP", 0
        p2life_filename:DB      "..\IMAGES\P2LIFE.BMP", 0
        p1_filename:    DB      "..\IMAGES\P1.BMP", 0
        p2_filename:    DB      "..\IMAGES\P2.BMP", 0
        p1punch_filename:DB     "..\IMAGES\P1PUNCH.BMP", 0
        p2punch_filename:DB     "..\IMAGES\P2PUNCH.BMP", 0
        p1kick_filename:DB      "..\IMAGES\P1KICK.BMP", 0
        p2kick_filename:DB      "..\IMAGES\P2KICK.BMP", 0

        ; Video mode active before the game started (restored on exit)
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
        ; Every load_sprite call takes (see SPRITE.ASM):
        ;       file name, destination segment, destination offset, width, height
        ; The sprite buffers themselves are declared in PLAYERS.ASM.

        ; Background (320x200, has its own segment)
        PUSH    WORD bg_filename
        PUSH    WORD bg_data
        PUSH    WORD bg_sprite
        PUSH    WORD 320
        PUSH    WORD 200
        CALL    load_sprite

        ; Players, idle pose (64x64)
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

        ; Attack poses (64x64), shown while the attack timer is running
        PUSH    WORD p1punch_filename
        PUSH    WORD data
        PUSH    WORD p1punch_sprite
        PUSH    WORD 64
        PUSH    WORD 64
        CALL    load_sprite

        PUSH    WORD p2punch_filename
        PUSH    WORD data
        PUSH    WORD p2punch_sprite
        PUSH    WORD 64
        PUSH    WORD 64
        CALL    load_sprite

        PUSH    WORD p1kick_filename
        PUSH    WORD data
        PUSH    WORD p1kick_sprite
        PUSH    WORD 64
        PUSH    WORD 64
        CALL    load_sprite

        PUSH    WORD p2kick_filename
        PUSH    WORD data
        PUSH    WORD p2kick_sprite
        PUSH    WORD 64
        PUSH    WORD 64
        CALL    load_sprite

        ; Life icons (8x8), one is drawn per life unit
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
        ; Frame pacing: the clock ISR raises sys_render_frame on every tick
        ; (~18.2 Hz). A frame only runs when the flag is set (and clears it);
        ; otherwise the loop just polls the quit key.
        CMP     BYTE [sys_render_frame], 1
        JE      run_frame
        JMP     check_quit
        run_frame:
        MOV     BYTE [sys_render_frame], 0


        ; Player 1 input processing
        ; The key flags (p1_a, p1_d, ...) are written by key_isr:
        ; 1 = held, 0 = released. Velocity is in pixels per frame and is
        ; applied later by move_p1.
        MOV WORD [p1_x_vel], 0     ; Reset vel

        CMP BYTE [p1_a], 1         ; Left pressed?
        JNE check_p1_right
        MOV WORD [p1_x_vel], -5    ; Move left

        check_p1_right:
        CMP BYTE [p1_d], 1         ; Right pressed?
        JNE check_p1_punch
        MOV WORD [p1_x_vel], 5     ; Move right

        ; Attacks: p1_punch / p1_kick ignore repeated calls (key lock + sprite
        ; timer), so it is safe to call them on every frame the key is down.
        check_p1_punch:
        CMP BYTE [p1_t], 1         ; Punch pressed?
        JNE check_p1_kick
        CALL p1_punch

        check_p1_kick:
        CMP BYTE [p1_r], 1         ; Kick pressed?
        JNE p2_input_processing
        CALL p1_kick

        p2_input_processing:
        ; Player 2 input processing (same logic as Player 1)
        MOV WORD [p2_x_vel], 0     ; Reset vel

        CMP BYTE [p2_left], 1      ; Left pressed?
        JNE check_p2_right
        MOV WORD [p2_x_vel], -5    ; Move left

        check_p2_right:
        CMP BYTE [p2_right], 1     ; Right pressed?
        JNE check_p2_punch
        MOV WORD [p2_x_vel], 5     ; Move right

        check_p2_punch:
        CMP BYTE [p2_m], 1         ; Punch pressed?
        JNE check_p2_kick
        CALL p2_punch

        check_p2_kick:
        CMP BYTE [p2_n], 1         ; Kick pressed?
        JNE update_positions
        CALL p2_kick

        update_positions:
        ; Applies the velocities to the positions (X is bounds-checked inside)
        CALL move_p1
        CALL move_p2

        ; Rendering: everything is drawn into the back buffer, background first
        ; and players on top, so the screen is only touched once (flip_screen)
        PUSH    WORD double_buffer_data
        PUSH    WORD bg_data
        PUSH    WORD bg_sprite
        CALL    show_bg
       
        PUSH WORD double_buffer_data
        CALL draw_players 
        ; Must run after draw_players: counts down the attack sprite timers and
        ; releases the attack locks of keys that are no longer held
        CALL update_attacks

        ; Copies the back buffer to video memory (waits for vertical retrace)
        PUSH    WORD double_buffer_data
        PUSH    WORD screen_buffer
        CALL    flip_screen

        ; Quit key (Q) is polled even on iterations that skip the frame
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

        ; Restoring the original ISRs (must be done before returning to DOS)
        CALL    reset_clock_isr
        CALL    reset_key_isr

        MOV     AH, 4CH
        MOV     AL, 00H         ; Error code (no error)
        INT     21H
;-----------------------------------------------------------------------------

segment stack stack
        resb 256
stacktop: