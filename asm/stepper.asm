.program stepper
    mov osr isr
    set x 6
loop:
    out pins 4 [2]
    jmp x-- loop
    out pins 4


