.program stepper
    mov osr isr
    set x 8
loop:
    out pins 4
    jmp x-- loop

