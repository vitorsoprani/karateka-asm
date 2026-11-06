GLOBAL  p1_sprite, p2_sprite, p1life_sprite, p2life_sprite
GLOBAL  p1_x, p1_y, p2_x, p2_y
GLOBAL  p1_x_vel, p1_y_vel, p2_x_vel, p2_y_vel
GLOBAL  p1_life, p2_life
GLOBAL  move_p1, move_p2, draw_players
GLOBAL  p1_punch, p2_punch, update_punches
GLOBAL  p1punch_sprite, p2punch_sprite

EXTERN  show_sprite
EXTERN  p1_t, p2_m              ; Punch keys (ISRS.ASM)

segment data
        ; -- Combat constants --
        PLAYER_W        EQU     60      ; Hurtbox width  (defender)
        PUNCH_W         EQU     60      ; Hitbox width   (attacker's punch)
        HITBOX_H        EQU     64      ; Box height (players and punch)
        PUNCH_FRAMES    EQU     2       ; Frames the punch sprite stays visible

        ; -- Player 1 Variables --
        p1_x            DW      50      ; Initial X position
        p1_y            DW      100     ; Initial Y position (floor level)
        p1_x_vel        DW      0
        p1_y_vel        DW      0
        p1_life         DW      10      ; Initial life (10 units)
        
        p1_sprite       RESB    4096    ; 64x64 buffer
        p1life_sprite   RESB    64      ; 8x8 buffer
        p1punch_sprite  RESB    4096    ; 64x64 buffer (punch pose)
        p1_punch_timer  DB      0       ; Frames left showing the punch sprite
        p1_punch_lock   DB      0       ; 1 = key still held (no auto-repeat)

        ; -- Player 2 Variables --
        p2_x            DW      200     ; Initial X position
        p2_y            DW      100     ; Initial Y position (floor level)
        p2_x_vel        DW      0
        p2_y_vel        DW      0
        p2_life         DW      10      ; Initial life (10 units)
        
        p2_sprite       RESB    4096    ; 64x64 buffer
        p2life_sprite   RESB    64      ; 8x8 buffer
        p2punch_sprite  RESB    4096    ; 64x64 buffer (punch pose)
        p2_punch_timer  DB      0
        p2_punch_lock   DB      0

segment code
;-- move_p1 function ---------------------------------------------------------
;       Updates Player 1 position based on velocity variables
; USAGE:
;       CALL
move_p1:
        PUSH    AX
        
        ; Updating X coordinate
        MOV     AX, [p1_x]
        ADD     AX, [p1_x_vel]
        
        ; Simple screen boundaries (0 to 320 - 64)
        CMP     AX, 0
        JL      skip_p1_x
        CMP     AX, 256
        JG      skip_p1_x
        MOV     [p1_x], AX

        skip_p1_x:
        ; Updating Y coordinate
        MOV     AX, [p1_y]
        ADD     AX, [p1_y_vel]
        MOV     [p1_y], AX

        POP     AX
        RET
;-----------------------------------------------------------------------------

;-- move_p2 function ---------------------------------------------------------
;       Updates Player 2 position based on velocity variables
; USAGE:
;       CALL
move_p2:
        PUSH    AX
        
        ; Updating X coordinate
        MOV     AX, [p2_x]
        ADD     AX, [p2_x_vel]
        
        ; Simple screen boundaries (0 to 320 - 64)
        CMP     AX, 0
        JL      skip_p2_x
        CMP     AX, 256
        JG      skip_p2_x
        MOV     [p2_x], AX

        skip_p2_x:
        ; Updating Y coordinate
        MOV     AX, [p2_y]
        ADD     AX, [p2_y_vel]
        MOV     [p2_y], AX

        POP     AX
        RET
;-----------------------------------------------------------------------------

;-- punch_collides function ---------------------------------------------------
;   Checks if p1 and p2 collide (horizontally)
; USAGE:
;       PUSH    atk_x
;       PUSH    atk_w
;       PUSH    def_x
;       PUSH    def_w
;       CALL    punch_collides
; RETURN:
;       AX = 1 if the boxes overlap, 0 otherwise (AX is NOT preserved)
punch_collides:
        PUSH    BP
        MOV     BP, SP

        ; atk_x < def_x + def_w ?
        MOV     AX, [BP + 6]            ; def_x
        ADD     AX, [BP + 4]            ; + def_w
        CMP     [BP + 10], AX           ; atk_x
        JGE     pc_miss

        ; def_x < atk_x + atk_w ?
        MOV     AX, [BP + 10]           ; atk_x
        ADD     AX, [BP + 8]            ; + atk_w
        CMP     [BP + 6], AX
        JGE     pc_miss

        MOV     AX, 1
        JMP     pc_exit
pc_miss:
        XOR     AX, AX
pc_exit:
        POP     BP
        RET     8                      ; 4 stack parameters
;-----------------------------------------------------------------------------

;-- p1_punch function --------------------------------------------------------
;       Player 1 punch. Call it when the punch key (T) is pressed.
;       Ignored while the previous punch animation is running or while the key
;       has not been released since the last punch (one key press = one punch).
;       Starts the punch sprite and, if the punch box overlaps Player 2,
;       removes one unit of Player 2's life.
; USAGE:
;       CALL    p1_punch
p1_punch:
        PUSH    AX

        CMP     BYTE [p1_punch_lock], 0
        JNE     p1_punch_exit
        CMP     BYTE [p1_punch_timer], 0
        JNE     p1_punch_exit

        MOV     BYTE [p1_punch_lock], 1
        MOV     BYTE [p1_punch_timer], PUNCH_FRAMES

        PUSH    WORD [p1_x]             ; atk_x
        PUSH    WORD PUNCH_W            ; atk_w
        PUSH    WORD [p2_x]             ; def_x
        PUSH    WORD PLAYER_W           ; def_w
        CALL    punch_collides
        CMP     AX, 0
        JE      p1_punch_exit

        CMP     WORD [p2_life], 0       ; never goes below zero
        JE      p1_punch_exit
        DEC     WORD [p2_life]

        p1_punch_exit:
        POP     AX
        RET
;-----------------------------------------------------------------------------

;-- p2_punch function --------------------------------------------------------
;       Same as p1_punch, for Player 2 (key M) hitting Player 1.
; USAGE:
;       CALL    p2_punch
p2_punch:
        PUSH    AX

        CMP     BYTE [p2_punch_lock], 0
        JNE     p2_punch_exit
        CMP     BYTE [p2_punch_timer], 0
        JNE     p2_punch_exit

        MOV     BYTE [p2_punch_lock], 1
        MOV     BYTE [p2_punch_timer], PUNCH_FRAMES

        PUSH    WORD [p2_x]             ; atk_x
        PUSH    WORD PUNCH_W            ; atk_w
        PUSH    WORD [p1_x]             ; def_x
        PUSH    WORD PLAYER_W           ; def_w
        CALL    punch_collides
        CMP     AX, 0
        JE      p2_punch_exit

        CMP     WORD [p1_life], 0
        JE      p2_punch_exit
        DEC     WORD [p1_life]

        p2_punch_exit:
        POP     AX
        RET
;-----------------------------------------------------------------------------

;-- update_punches function --------------------------------------------------
;       Per-frame upkeep of the punch state. Call once per frame, AFTER
;       draw_players (so the sprite is shown for exactly PUNCH_FRAMES frames).
;         - counts down the punch sprite timers
;         - releases the punch lock when the key is no longer pressed
; USAGE:
;       CALL    update_punches
update_punches:
        CMP     BYTE [p1_punch_timer], 0
        JE      up_p1_key
        DEC     BYTE [p1_punch_timer]
        up_p1_key:
        CMP     BYTE [p1_t], 0
        JNE     up_p2_timer
        MOV     BYTE [p1_punch_lock], 0

        up_p2_timer:
        CMP     BYTE [p2_punch_timer], 0
        JE      up_p2_key
        DEC     BYTE [p2_punch_timer]
        up_p2_key:
        CMP     BYTE [p2_m], 0
        JNE     up_exit
        MOV     BYTE [p2_punch_lock], 0

        up_exit:
        RET
;-----------------------------------------------------------------------------

;-- draw_players function ----------------------------------------------------
;       Draws both players and their life indicators
; USAGE:
;       PUSH    dest_segment    (double_buffer_data segment)
;       CALL    draw_players

draw_players:
        PUSH    BP
        MOV     BP, SP
        PUSHF
        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DX

        MOV     AX, [BP + 4]    ; Retrieves dest_segment from stack

        ; --- Drawing Player 1 (punch pose while the punch timer is running) ---
        MOV     DX, p1_sprite
        CMP     BYTE [p1_punch_timer], 0
        JE      draw_p1_body
        MOV     DX, p1punch_sprite
        draw_p1_body:
        PUSH    AX              ; dest_segment
        PUSH    WORD data       ; sprite_segment 
        PUSH    DX              ; sprite_addr
        PUSH    WORD 64         ; width
        PUSH    WORD 64         ; height
        PUSH    WORD [p1_x]     ; x
        PUSH    WORD [p1_y]     ; y
        CALL    show_sprite

        ; --- Drawing Player 2 (punch pose while the punch timer is running) ---
        MOV     DX, p2_sprite
        CMP     BYTE [p2_punch_timer], 0
        JE      draw_p2_body
        MOV     DX, p2punch_sprite
        draw_p2_body:
        PUSH    AX              ; dest_segment
        PUSH    WORD data       ; sprite_segment 
        PUSH    DX              ; sprite_addr
        PUSH    WORD 64         ; width
        PUSH    WORD 64         ; height
        PUSH    WORD [p2_x]     ; x
        PUSH    WORD [p2_y]     ; y
        CALL    show_sprite


        ; --- Drawing Player 1 Life (Bottom-Left) ---
        MOV     CX, [p1_life]
        CMP     CX, 0
        JE      skip_p1_life    ; If life is 0, draw nothing
        MOV     BX, 10          ; X of the first flag (life indicator)
        
        draw_p1_life_loop:
                PUSH    CX
                
                PUSH    AX                  ; dest_segment
                PUSH    WORD data           ; sprite_segment
                PUSH    WORD p1life_sprite  ; sprite_addr
                PUSH    WORD 8              ; width
                PUSH    WORD 8              ; height
                PUSH    BX                  ; X dinâmico
                PUSH    WORD 185            ; Y Fixo no inferior da tela
                CALL    show_sprite

                ADD     BX, 10              ; padding to the next flag

                POP     CX
        LOOP    draw_p1_life_loop
        skip_p1_life:


        ; --- Drawing Player 2 Life (Bottom-Right) ---
        MOV     CX, [p2_life]
        CMP     CX, 0
        JE      skip_p2_life
        MOV     BX, 302
        
        draw_p2_life_loop:
                PUSH    CX
                
                PUSH    AX                  ; dest_segment
                PUSH    WORD data           ; sprite_segment
                PUSH    WORD p2life_sprite  ; sprite_addr
                PUSH    WORD 8              ; width
                PUSH    WORD 8              ; height
                PUSH    BX                  ; X dinâmico
                PUSH    WORD 185            ; Y Fixo no inferior da tela
                CALL    show_sprite

                SUB     BX, 10

                POP     CX
        LOOP    draw_p2_life_loop
        skip_p2_life:

        POP     DX
        POP     CX
        POP     BX
        POP     AX
        POPF
        POP     BP
        RET     2
;-----------------------------------------------------------------------------
