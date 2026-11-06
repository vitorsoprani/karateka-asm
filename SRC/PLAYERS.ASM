GLOBAL  p1_sprite, p2_sprite, p1life_sprite, p2life_sprite
GLOBAL  p1_x, p1_y, p2_x, p2_y
GLOBAL  p1_x_vel, p1_y_vel, p2_x_vel, p2_y_vel
GLOBAL  p1_life, p2_life
GLOBAL  move_p1, move_p2, draw_players

EXTERN  show_sprite

segment data
        ; -- Player 1 Variables --
        p1_x            DW      50      ; Initial X position
        p1_y            DW      100     ; Initial Y position (floor level)
        p1_x_vel        DW      0
        p1_y_vel        DW      0
        p1_life         DW      10      ; Initial life (10 units)
        
        p1_sprite       RESB    4096    ; 64x64 buffer
        p1life_sprite   RESB    64      ; 8x8 buffer

        ; -- Player 2 Variables --
        p2_x            DW      200     ; Initial X position
        p2_y            DW      100     ; Initial Y position (floor level)
        p2_x_vel        DW      0
        p2_y_vel        DW      0
        p2_life         DW      10      ; Initial life (10 units)
        
        p2_sprite       RESB    4096    ; 64x64 buffer
        p2life_sprite   RESB    64      ; 8x8 buffer

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

        MOV     AX, [BP + 4]    ; Retrieves dest_segment from stack

        ; --- Drawing Player 1 ---
        PUSH    AX              ; dest_segment
        PUSH    WORD data       ; sprite_segment 
        PUSH    WORD p1_sprite  ; sprite_addr
        PUSH    WORD 64         ; width
        PUSH    WORD 64         ; height
        PUSH    WORD [p1_x]     ; x
        PUSH    WORD [p1_y]     ; y
        CALL    show_sprite

        ; --- Drawing Player 2 ---
        PUSH    AX              ; dest_segment
        PUSH    WORD data       ; sprite_segment 
        PUSH    WORD p2_sprite  ; sprite_addr
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

        POP     CX
        POP     BX
        POP     AX
        POPF
        POP     BP
        RET     2
;-----------------------------------------------------------------------------