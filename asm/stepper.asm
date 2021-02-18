.program stepper
    mov osr isr
    set x 6
loop:
    out pins 4 [1]
    jmp x-- loop
    out pins 4


