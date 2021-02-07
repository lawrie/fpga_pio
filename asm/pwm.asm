.program pwm
.side_set 1 opt
    pull noblock    side 0
    mov x osr
    mov y isr
countloop:
    jmp x!=y noset
    jmp skip        side 1
noset:
    nop
skip:
    jmp y-- countloop
 

