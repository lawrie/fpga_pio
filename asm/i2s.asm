.program i2s
.side_set 2
    pull noblock  side 3
    mov x osr     side 3
    set y 14      side 3 [1]
loop1:
    out pins 1    side 2 [3]
    jmp y-- loop1 side 3 [3]
    out pins 1    side 0 [3]
    set y 14      side 1 [3]
loop0:
    out pins 1    side 0 [3]
    jmp y-- loop0 side 1 [3]
    out pins 1    side 2 [3]
    
