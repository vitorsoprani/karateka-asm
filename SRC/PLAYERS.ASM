;=============================================================================
; PLAYERS.ASM
;       Player state and behavior: position, movement, life, punch/kick and
;       rendering of both players with their life indicators.
;       Attacks work as follows (see p*_punch / p*_kick / update_attacks):
;         - one key press = one attack (a lock holds until the key is released)
;         - the attack sprite stays visible for ATTACK_FRAMES frames
;         - the hit test and the damage are resolved when the attack starts
;=============================================================================

GLOBAL  p1_sprite, p2_sprite, p1life_sprite, p2life_sprite
GLOBAL  p1_x, p1_y, p2_x, p2_y
GLOBAL  p1_x_vel, p1_y_vel, p2_x_vel, p2_y_vel
GLOBAL  p1_life, p2_life
GLOBAL  move_p1, move_p2, draw_players
GLOBAL  p1_punch, p2_punch, p1_kick, p2_kick, update_attacks
GLOBAL  p1punch_sprite, p2punch_sprite, p1kick_sprite, p2kick_sprite

EXTERN  show_sprite
EXTERN  p1_t, p2_m              ; Punch keys (ISRS.ASM)
EXTERN  p1_r, p2_n              ; Kick keys  (ISRS.ASM)

segment data
        ; -- Combat constants --
        ; Collision is horizontal only: the Y axis is never tested
        PLAYER_W        EQU     60      ; Hurtbox width  (defender)
        ATTACK_W        EQU     60      ; Hitbox width   (attacker: punch and kick)
        ATTACK_FRAMES   EQU     2       ; Frames the punch/kick sprite stays visible

        ; -- Player 1 Variables --
        ; x, y         = top-left corner of the sprite on screen (pixels)
        ; x_vel, y_vel = displacement applied per frame by move_p1
        p1_x            DW      50      ; Initial X position
        p1_y            DW      100     ; Initial Y position (floor level)
        p1_x_vel        DW      0
        p1_y_vel        DW      0
        p1_life         DW      10      ; Initial life (10 units)
        
        ; Sprite buffers are filled by load_sprite (MAIN.ASM) at startup
        p1_sprite       RESB    4096    ; 64x64 buffer
        p1life_sprite   RESB    64      ; 8x8 buffer
        p1punch_sprite  RESB    4096    ; 64x64 buffer (punch pose)
        p1_punch_timer  DB      0       ; Frames left showing the punch sprite
        p1_punch_lock   DB      0       ; 1 = key still held (no auto-repeat)
        p1kick_sprite   RESB    4096    ; 64x64 buffer (kick pose)
        p1_kick_timer   DB      0       ; Frames left showing the kick sprite
        p1_kick_lock    DB      0       ; 1 = key still held (no auto-repeat)

        ; -- Player 2 Variables (same fields and meaning as Player 1) --
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
        p2kick_sprite   RESB    4096    ; 64x64 buffer (kick pose)
        p2_kick_timer   DB      0
        p2_kick_lock    DB      0

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
        
        ; Screen boundaries: X must stay within 0..256 (320 - 64 sprite width).
        ; A move that would leave this range is discarded entirely (no
        ; clamping), so the player may stop a few pixels short of the edge.
        CMP     AX, 0
        JL      skip_p1_x
        CMP     AX, 256
        JG      skip_p1_x
        MOV     [p1_x], AX

        skip_p1_x:
        ; Updating Y coordinate (no bounds check)
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
        
        ; Screen boundaries: X must stay within 0..256 (320 - 64 sprite width).
        ; A move that would leave this range is discarded entirely (no
        ; clamping), so the player may stop a few pixels short of the edge.
        CMP     AX, 0
        JL      skip_p2_x
        CMP     AX, 256
        JG      skip_p2_x
        MOV     [p2_x], AX

        skip_p2_x:
        ; Updating Y coordinate (no bounds check)
        MOV     AX, [p2_y]
        ADD     AX, [p2_y_vel]
        MOV     [p2_y], AX

        POP     AX
        RET
;-----------------------------------------------------------------------------

;-- attack_collides function --------------------------------------------------
;       Horizontal (x / width) overlap test between the attacker's hitbox and
;       the defender's hurtbox. Shared by punches and kicks.
;       The boxes overlap when each one starts before the other one ends, so
;       the test is symmetric: there is no facing direction (the attack
;       reaches both sides) and the Y axis is ignored.
; USAGE:
;       PUSH    atk_x
;       PUSH    atk_w
;       PUSH    def_x
;       PUSH    def_w
;       CALL    attack_collides
; RETURN:
;       AX = 1 if the boxes overlap, 0 otherwise (AX is NOT preserved)
attack_collides:
        PUSH    BP
        MOV     BP, SP

        ; Stack layout: [BP+10]=atk_x  [BP+8]=atk_w  [BP+6]=def_x  [BP+4]=def_w

        ; atk_x < def_x + def_w ?
        MOV     AX, [BP + 6]            ; def_x
        ADD     AX, [BP + 4]            ; + def_w
        CMP     [BP + 10], AX           ; atk_x
        JGE     ac_miss

        ; def_x < atk_x + atk_w ?
        MOV     AX, [BP + 10]           ; atk_x
        ADD     AX, [BP + 8]            ; + atk_w
        CMP     [BP + 6], AX            ; def_x
        JGE     ac_miss

        MOV     AX, 1
        JMP     ac_exit
ac_miss:
        XOR     AX, AX
ac_exit:
        POP     BP
        RET     8                       ; 4 stack parameters
;-----------------------------------------------------------------------------

;-- p1_punch function --------------------------------------------------------
;       Player 1 punch. Call it when the punch key (T) is pressed.
;       Ignored while any attack animation (punch or kick) is running or while
;       the key has not been released since the last punch (one press = one punch).
;       Starts the punch sprite and, if the attack box overlaps Player 2,
;       removes one unit of Player 2's life.
; USAGE:
;       CALL    p1_punch
p1_punch:
        PUSH    AX

        ; Guards: ignored if the key was not released since the last punch,
        ; if the punch sprite is still showing, or if a kick is in progress
        CMP     BYTE [p1_punch_lock], 0
        JNE     p1_punch_exit
        CMP     BYTE [p1_punch_timer], 0
        JNE     p1_punch_exit
        CMP     BYTE [p1_kick_timer], 0       ; cannot punch during a kick
        JNE     p1_punch_exit

        ; Attack accepted: lock until the key is released and start the sprite
        ; timer (both happen even if the punch misses). The hit test and the
        ; damage are resolved right now, on the frame the punch starts.
        MOV     BYTE [p1_punch_lock], 1
        MOV     BYTE [p1_punch_timer], ATTACK_FRAMES

        PUSH    WORD [p1_x]             ; atk_x
        PUSH    WORD ATTACK_W           ; atk_w
        PUSH    WORD [p2_x]             ; def_x
        PUSH    WORD PLAYER_W           ; def_w
        CALL    attack_collides
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
;       Player 2 punch. Call it when the punch key (M) is pressed.
;       Ignored while any attack animation (punch or kick) is running or while
;       the key has not been released since the last punch (one press = one punch).
;       Starts the punch sprite and, if the attack box overlaps Player 1,
;       removes one unit of Player 1's life.
; USAGE:
;       CALL    p2_punch
p2_punch:
        PUSH    AX

        ; Guards: ignored if the key was not released since the last punch,
        ; if the punch sprite is still showing, or if a kick is in progress
        CMP     BYTE [p2_punch_lock], 0
        JNE     p2_punch_exit
        CMP     BYTE [p2_punch_timer], 0
        JNE     p2_punch_exit
        CMP     BYTE [p2_kick_timer], 0       ; cannot punch during a kick
        JNE     p2_punch_exit

        ; Attack accepted: lock until the key is released and start the sprite
        ; timer (both happen even if the punch misses). The hit test and the
        ; damage are resolved right now, on the frame the punch starts.
        MOV     BYTE [p2_punch_lock], 1
        MOV     BYTE [p2_punch_timer], ATTACK_FRAMES

        PUSH    WORD [p2_x]             ; atk_x
        PUSH    WORD ATTACK_W           ; atk_w
        PUSH    WORD [p1_x]             ; def_x
        PUSH    WORD PLAYER_W           ; def_w
        CALL    attack_collides
        CMP     AX, 0
        JE      p2_punch_exit

        CMP     WORD [p1_life], 0       ; never goes below zero
        JE      p2_punch_exit
        DEC     WORD [p1_life]

        p2_punch_exit:
        POP     AX
        RET
;-----------------------------------------------------------------------------

;-- p1_kick function --------------------------------------------------------
;       Player 1 kick. Call it when the kick key (R) is pressed.
;       Ignored while any attack animation (punch or kick) is running or while
;       the key has not been released since the last kick (one press = one kick).
;       Starts the kick sprite and, if the attack box overlaps Player 2,
;       removes one unit of Player 2's life.
; USAGE:
;       CALL    p1_kick
p1_kick:
        PUSH    AX

        ; Guards: ignored if the key was not released since the last kick,
        ; if the kick sprite is still showing, or if a punch is in progress
        CMP     BYTE [p1_kick_lock], 0
        JNE     p1_kick_exit
        CMP     BYTE [p1_kick_timer], 0
        JNE     p1_kick_exit
        CMP     BYTE [p1_punch_timer], 0       ; cannot kick during a punch
        JNE     p1_kick_exit

        ; Attack accepted: lock until the key is released and start the sprite
        ; timer (both happen even if the kick misses). The hit test and the
        ; damage are resolved right now, on the frame the kick starts.
        MOV     BYTE [p1_kick_lock], 1
        MOV     BYTE [p1_kick_timer], ATTACK_FRAMES

        PUSH    WORD [p1_x]             ; atk_x
        PUSH    WORD ATTACK_W           ; atk_w
        PUSH    WORD [p2_x]             ; def_x
        PUSH    WORD PLAYER_W           ; def_w
        CALL    attack_collides
        CMP     AX, 0
        JE      p1_kick_exit

        CMP     WORD [p2_life], 0       ; never goes below zero
        JE      p1_kick_exit
        DEC     WORD [p2_life]

        p1_kick_exit:
        POP     AX
        RET
;-----------------------------------------------------------------------------

;-- p2_kick function --------------------------------------------------------
;       Player 2 kick. Call it when the kick key (N) is pressed.
;       Ignored while any attack animation (punch or kick) is running or while
;       the key has not been released since the last kick (one press = one kick).
;       Starts the kick sprite and, if the attack box overlaps Player 1,
;       removes one unit of Player 1's life.
; USAGE:
;       CALL    p2_kick
p2_kick:
        PUSH    AX

        ; Guards: ignored if the key was not released since the last kick,
        ; if the kick sprite is still showing, or if a punch is in progress
        CMP     BYTE [p2_kick_lock], 0
        JNE     p2_kick_exit
        CMP     BYTE [p2_kick_timer], 0
        JNE     p2_kick_exit
        CMP     BYTE [p2_punch_timer], 0       ; cannot kick during a punch
        JNE     p2_kick_exit

        ; Attack accepted: lock until the key is released and start the sprite
        ; timer (both happen even if the kick misses). The hit test and the
        ; damage are resolved right now, on the frame the kick starts.
        MOV     BYTE [p2_kick_lock], 1
        MOV     BYTE [p2_kick_timer], ATTACK_FRAMES

        PUSH    WORD [p2_x]             ; atk_x
        PUSH    WORD ATTACK_W           ; atk_w
        PUSH    WORD [p1_x]             ; def_x
        PUSH    WORD PLAYER_W           ; def_w
        CALL    attack_collides
        CMP     AX, 0
        JE      p2_kick_exit

        CMP     WORD [p1_life], 0       ; never goes below zero
        JE      p2_kick_exit
        DEC     WORD [p1_life]

        p2_kick_exit:
        POP     AX
        RET
;-----------------------------------------------------------------------------

;-- update_attacks function --------------------------------------------------
;       Per-frame upkeep of the attack state (punch and kick). Call once per
;       frame, AFTER draw_players (so each sprite is shown for exactly
;       ATTACK_FRAMES frames).
;         - counts down the sprite timers
;         - releases each lock when its key is no longer pressed
; USAGE:
;       CALL    update_attacks
update_attacks:
        ; --- Player 1 punch ---
        CMP     BYTE [p1_punch_timer], 0
        JE      ua_p1_punch_key
        DEC     BYTE [p1_punch_timer]
        ua_p1_punch_key:
        CMP     BYTE [p1_t], 0
        JNE     ua_p1_kick
        MOV     BYTE [p1_punch_lock], 0

        ; --- Player 1 kick ---
        ua_p1_kick:
        CMP     BYTE [p1_kick_timer], 0
        JE      ua_p1_kick_key
        DEC     BYTE [p1_kick_timer]
        ua_p1_kick_key:
        CMP     BYTE [p1_r], 0
        JNE     ua_p2_punch
        MOV     BYTE [p1_kick_lock], 0

        ; --- Player 2 punch ---
        ua_p2_punch:
        CMP     BYTE [p2_punch_timer], 0
        JE      ua_p2_punch_key
        DEC     BYTE [p2_punch_timer]
        ua_p2_punch_key:
        CMP     BYTE [p2_m], 0
        JNE     ua_p2_kick
        MOV     BYTE [p2_punch_lock], 0

        ; --- Player 2 kick ---
        ua_p2_kick:
        CMP     BYTE [p2_kick_timer], 0
        JE      ua_p2_kick_key
        DEC     BYTE [p2_kick_timer]
        ua_p2_kick_key:
        CMP     BYTE [p2_n], 0
        JNE     ua_exit
        MOV     BYTE [p2_kick_lock], 0

        ua_exit:
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

        ; Retrieves dest_segment from stack. AX keeps it during the whole
        ; function (show_sprite preserves the registers).
        MOV     AX, [BP + 4]

        ; Drawing order: Player 1, Player 2 (overlaps Player 1 when they
        ; intersect), then the life icons.
        ; DX = sprite to draw: idle by default, attack pose while its timer runs.
        ; --- Drawing Player 1 (punch/kick pose while its timer is running) ---
        MOV     DX, p1_sprite
        CMP     BYTE [p1_punch_timer], 0
        JE      draw_p1_check_kick
        MOV     DX, p1punch_sprite
        JMP     draw_p1_body
        draw_p1_check_kick:
        CMP     BYTE [p1_kick_timer], 0
        JE      draw_p1_body
        MOV     DX, p1kick_sprite
        draw_p1_body:
        PUSH    AX              ; dest_segment
        PUSH    WORD data       ; sprite_segment 
        PUSH    DX              ; sprite_addr
        PUSH    WORD 64         ; width
        PUSH    WORD 64         ; height
        PUSH    WORD [p1_x]     ; x
        PUSH    WORD [p1_y]     ; y
        CALL    show_sprite

        ; --- Drawing Player 2 (punch/kick pose while its timer is running) ---
        MOV     DX, p2_sprite
        CMP     BYTE [p2_punch_timer], 0
        JE      draw_p2_check_kick
        MOV     DX, p2punch_sprite
        JMP     draw_p2_body
        draw_p2_check_kick:
        CMP     BYTE [p2_kick_timer], 0
        JE      draw_p2_body
        MOV     DX, p2kick_sprite
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
        ; One icon per life unit, 10 px apart (8 px icon + 2 px gap). Player 1
        ; icons grow to the right from x=10; Player 2 icons are mirrored: they
        ; start at x=302 (320 - 10 - 8) and grow to the left.
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
                PUSH    BX                  ; X of the current icon
                PUSH    WORD 185            ; Fixed Y (bottom of the screen)
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
                PUSH    BX                  ; X of the current icon
                PUSH    WORD 185            ; Fixed Y (bottom of the screen)
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
