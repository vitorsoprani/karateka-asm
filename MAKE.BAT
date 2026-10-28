CALL    NASM16          .\SRC\MAIN.ASM -f obj -o .\OBJ\MAIN.OBJ

CALL    FREELINK        .\OBJ\MAIN.OBJ, .\GAME.EXE
