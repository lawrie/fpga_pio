.program stepper
    pull block
    mov isr osr
    pull block
    mov y osr
outer:
    mov osr isr 
    set x 6
inner:
    out pins 4 [2]
    jmp x-- inner
    out pins 4
    jmp y-- outer
wrap_target:
    out pins 4
    jmp wrap_target

