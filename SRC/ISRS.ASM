GLOBAL set_clock_isr, set_key_isr, reset_clock_isr, reset_key_isr
GLOBAL p1_w, p1_a, p1_s, p1_d, p1_r, p1_t
GLOBAL p2_up, p2_left, p2_down, p2_right, p2_n, p2_m
GLOBAL sys_p, sys_q
GLOBAL sys_render_frame

segment data
        clk_int         EQU     08h     ; Clk interruption number
        key_int         EQU     09h     ; Keyboard interruption number
        kb_data         EQU     60h     ; Data port from 8255
        kb_ctrl         EQU     61h     ; Control port from 8255
        pic_ctrl        EQU     20h     ; PIC control port
        eoi             EQU     20h     ; End of interruption code

        ; Timer variables
        clk_isr_ip      DW      0
        clk_isr_cs      DW      0
        ticks           DB      0
        seconds         DB      0
        minutes         DB      0
        hours           DB      0

        ; Keyboard variables
        key_isr_ip      DW      0
        key_isr_cs      DW      0

        ; Command variables
        ; p1 controls
        p1_w            DB      0       ; Jump
        p1_a            DB      0       ; Left
        p1_s            DB      0       ; Down
        p1_d            DB      0       ; Right
        p1_r            DB      0       ; Kick
        p1_t            DB      0       ; Punch

        ; P2 controls
        p2_up           DB      0
        p2_left         DB      0
        p2_down         DB      0
        p2_right        DB      0
        p2_n            DB      0
        p2_m            DB      0

        ; systemm controls
        sys_p               DB  0       ; Pause
        sys_q               DB  0       ; Quit
        sys_render_frame    DB  0

segment code

set_clock_isr:
        PUSH    AX
        PUSH    ES
        CLI                             ; Disable interruptions
        XOR     AX, AX
        MOV     ES, AX
        MOV     AX, [ES:clk_int*4]      ; Saves IP
        MOV     [clk_isr_ip], AX
        MOV     AX, [ES:clk_int*4+2]    ; Saves CS
        MOV     [clk_isr_cs], AX
        MOV     WORD [ES:clk_int*4], clk_isr
        MOV     [ES:clk_int*4+2], CS    ; Sets the isr
        STI
        POP     ES
        POP     AX
        RET

set_key_isr:
        PUSH    AX
        PUSH    ES
        CLI
        XOR     AX, AX
        MOV     ES, AX
        MOV     AX, [ES:key_int*4]
        MOV     [key_isr_ip], AX
        MOV     AX, [ES:key_int*4+2]
        MOV     [key_isr_cs], AX
        MOV     WORD [ES:key_int*4], key_isr
        MOV     [ES:key_int*4+2], CS
        STI
        POP     ES
        POP     AX
        RET

reset_clock_isr:
        PUSH    AX
        PUSH    ES
        CLI
        XOR     AX, AX
        MOV     ES, AX
        MOV     AX, [clk_isr_ip]        ; Restore original IP
        MOV     [ES:clk_int*4], AX
        MOV     AX, [clk_isr_cs]        ; Restore original CS
        MOV     [ES:clk_int*4+2], AX
        STI
        POP     ES
        POP     AX
        RET

reset_key_isr:
        PUSH    AX
        PUSH    ES
        CLI
        XOR     AX, AX
        MOV     ES, AX
        MOV     AX, [key_isr_ip]
        MOV     [ES:key_int*4], AX
        MOV     AX, [key_isr_cs]
        MOV     [ES:key_int*4+2], AX
        STI
        POP     ES
        POP     AX
        RET
;-----------------------------------------------------------------------------

;-- Clock interruption ISR ---------------------------------------------------
clk_isr:
        PUSH    AX
        PUSH    DS

        MOV     AX, data
        MOV     DS, AX

        MOV     byte [sys_render_frame], 1 

        INC     byte [ticks]
        CMP     byte [ticks], 18        ; 18hz clock, 18 clicks == 1s
        JB      quit_clk_isr            
        MOV     byte [ticks], 0         

        INC     byte [seconds]          
        CMP     byte [seconds], 60
        JB      quit_clk_isr
        MOV     byte [seconds], 0

        INC     byte [minutes]
        CMP     byte [minutes], 60
        JB      quit_clk_isr
        MOV     byte [minutes], 0

        INC     byte [hours]
        CMP     byte [hours], 24
        JB      quit_clk_isr
        MOV     byte [hours], 0

quit_clk_isr:
        MOV     AL, eoi                 
        OUT     pic_ctrl, AL            ; Sends EOI to the pic[cite: 1, 5]
        POP     DS
        POP     AX
        IRET
;-----------------------------------------------------------------------------

;-- Keyboard interruption ISR ------------------------------------------------
key_isr:
        PUSH    AX
        PUSH    DS

        MOV     AX, data        ; Because we change ds on sprite functions.
        MOV     DS, AX

        IN      AL, kb_data             ; Read sanscode in port 60H

        ; Separate make and Break sanscodes
        MOV     AH, 1                   ; Assume Make code (Estado = 1)
        TEST    AL, 80h                 ; Verifica se o bit 7 está setado
        JZ      process_key             ; Se não estiver, é Make code (pula direto)
        MOV     AH, 0                   ; Se estiver, é Break code (Estado = 0)
        AND     AL, 7Fh                 ; Limpa o bit 7 para isolar o scancode

process_key:
        ; --- Player 1 ---
        CMP     AL, 11h                 ; W
        JNE     check_p1_a
        MOV     [p1_w], AH
        JMP     end_key_isr
check_p1_a:
        CMP     AL, 1Eh                 ; A
        JNE     check_p1_s
        MOV     [p1_a], AH
        JMP     end_key_isr
check_p1_s:
        CMP     AL, 1Fh                 ; S
        JNE     check_p1_d
        MOV     [p1_s], AH
        JMP     end_key_isr
check_p1_d:
        CMP     AL, 20h                 ; D
        JNE     check_p1_r
        MOV     [p1_d], AH
        JMP     end_key_isr
check_p1_r:
        CMP     AL, 13h                 ; R
        JNE     check_p1_t
        MOV     [p1_r], AH
        JMP     end_key_isr
check_p1_t:
        CMP     AL, 14h                 ; T
        JNE     check_p2_up
        MOV     [p1_t], AH
        JMP     end_key_isr

        ; --- Player 2 ---
check_p2_up:
        CMP     AL, 48h                 ; Up Arrow
        JNE     check_p2_left
        MOV     [p2_up], AH
        JMP     end_key_isr
check_p2_left:
        CMP     AL, 4Bh                 ; Left Arrow
        JNE     check_p2_down
        MOV     [p2_left], AH
        JMP     end_key_isr
check_p2_down:
        CMP     AL, 50h                 ; Down Arrow
        JNE     check_p2_right
        MOV     [p2_down], AH
        JMP     end_key_isr
check_p2_right:
        CMP     AL, 4Dh                 ; Right Arrow
        JNE     check_p2_n
        MOV     [p2_right], AH
        JMP     end_key_isr
check_p2_n:
        CMP     AL, 31h                 ; N
        JNE     check_p2_m
        MOV     [p2_n], AH
        JMP     end_key_isr
check_p2_m:
        CMP     AL, 32h                 ; M
        JNE     check_sys_p
        MOV     [p2_m], AH
        JMP     end_key_isr

        ; --- System ---
check_sys_p:
        CMP     AL, 19h                 ; P (Pause)
        JNE     check_sys_q
        MOV     [sys_p], AH
        JMP     end_key_isr
check_sys_q:
        CMP     AL, 10h                 ; Q (Quit)
        JNE     end_key_isr
        MOV     [sys_q], AH

end_key_isr:
        ; Reset do controlador do teclado
        IN      AL, kb_ctrl             
        OR      AL, 80h                 
        OUT     kb_ctrl, AL
        AND     AL, 7Fh                 
        OUT     kb_ctrl, AL             ; "Frees" the keyboard

        MOV     AL, eoi                 
        OUT     pic_ctrl, AL            ; Sends EOI to the PIC

        POP     DS
        POP     AX
        IRET
;-----------------------------------------------------------------------------
