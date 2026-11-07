;=============================================================================
; ISRS.ASM
;       Hardware interrupt handling: system timer (INT 08h) and keyboard
;       (INT 09h).
;         - clk_isr : paces the game (raises sys_render_frame on every tick)
;                     and keeps a software clock
;         - key_isr : translates keyboard scancodes into per-key flags
;                     (1 = held, 0 = released) read by the main loop
;       set_*_isr saves the original vector and installs ours; reset_*_isr
;       restores it.
;=============================================================================

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
        ; Original INT 08h vector (saved by set_clock_isr)
        clk_isr_ip      DW      0
        clk_isr_cs      DW      0
        ; Software clock kept by clk_isr (ticks -> seconds -> minutes -> hours)
        ticks           DB      0
        seconds         DB      0
        minutes         DB      0
        hours           DB      0

        ; Keyboard variables: original INT 09h vector (saved by set_key_isr)
        key_isr_ip      DW      0
        key_isr_cs      DW      0

        ; Command variables: key state flags written by key_isr
        ;       1 = key held down, 0 = key released
        ; p1 controls
        p1_w            DB      0       ; Jump
        p1_a            DB      0       ; Left
        p1_s            DB      0       ; Down
        p1_d            DB      0       ; Right
        p1_r            DB      0       ; Kick
        p1_t            DB      0       ; Punch

        ; P2 controls (arrow keys + N / M)
        p2_up           DB      0       ; Jump  (Up arrow)
        p2_left         DB      0       ; Left  (Left arrow)
        p2_down         DB      0       ; Down  (Down arrow)
        p2_right        DB      0       ; Right (Right arrow)
        p2_n            DB      0       ; Kick  (N)
        p2_m            DB      0       ; Punch (M)

        ; System controls
        sys_p               DB  0       ; Pause
        sys_q               DB  0       ; Quit
        sys_render_frame    DB  0       ; Frame pacing: set by clk_isr every tick,
                                        ; cleared by the main loop

segment code

;-- set_clock_isr / set_key_isr / reset_clock_isr / reset_key_isr ------------
;       set_*   : saves the original vector from the Interrupt Vector Table
;                 and installs our ISR in its place
;       reset_* : puts the original vector back (call before exiting to DOS)
;       The IVT entry of INT n is 4 bytes at 0000:n*4 (IP word first, then CS
;       word). Interrupts are disabled while it is rewritten.
; USAGE:
;       CALL    set_clock_isr   /   CALL    set_key_isr
;       CALL    reset_clock_isr /   CALL    reset_key_isr
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
; Runs on every timer tick (INT 08h, ~18.2 Hz):
;       - raises sys_render_frame, which paces the main loop
;       - updates the software clock
clk_isr:
        PUSH    AX
        PUSH    DS

        MOV     AX, data                ; DS is unknown when the interrupt fires
        MOV     DS, AX

        MOV     byte [sys_render_frame], 1      ; A new frame may run

        ; Each stage below only advances when the previous one wrapped around
        INC     byte [ticks]
        CMP     byte [ticks], 18        ; ~18.2 Hz timer: 18 ticks ~= 1 s
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
        OUT     pic_ctrl, AL            ; Sends EOI to the PIC
        POP     DS
        POP     AX
        IRET
;-----------------------------------------------------------------------------

;-- Keyboard interruption ISR ------------------------------------------------
; Runs on every keyboard event (INT 09h). The controller sends one scancode
; per event: bit 7 clear = key pressed (make), bit 7 set = key released
; (break); the remaining 7 bits identify the key. The ISR stores the key state
; in the matching flag (1 = held, 0 = released); the main loop only reads
; those flags.
key_isr:
        PUSH    AX
        PUSH    DS

        MOV     AX, data        ; DS may hold another segment (sprite functions change it)
        MOV     DS, AX

        IN      AL, kb_data             ; Read scancode from port 60h

        ; Separate make and break scancodes (AH = resulting key state)
        MOV     AH, 1                   ; Assume make code (state = 1)
        TEST    AL, 80h                 ; Is bit 7 set?
        JZ      process_key             ; No: it is a make code
        MOV     AH, 0                   ; Yes: break code (state = 0)
        AND     AL, 7Fh                 ; Clear bit 7 to isolate the scancode

process_key:
        ; Dispatch: compares AL with each mapped scancode and stores the state
        ; (AH) in the matching flag. Unmapped scancodes are ignored. Arrow keys
        ; arrive as 0E0h followed by their scancode: the 0E0h byte matches
        ; nothing and is ignored, the following byte is handled normally.
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
        ; Acknowledge the scancode to the keyboard controller: pulse bit 7 of
        ; port 61h (set, then clear)
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
