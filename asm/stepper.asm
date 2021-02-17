.program stepper
    mov osr y
    set x 8
loop:
    out pins 4
    jmp x-- loop

