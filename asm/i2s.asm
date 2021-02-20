.program i2s
.side_set 2
    pull noblock  side 1
    mov x osr     side 1
    set y 14      side 1
loop1:
    out pins 1    side 2 [2]
    jmp y-- loop1 side 3 [2]
    out pins 1    side 2 [2]
    set y 14      side 3 [2]
loop0:
    out pins 1    side 0 [2]
    jmp y-- loop0 side 1 [2]
    out pins 1    side 0 [2]
    
