.program uart_tx
.side_set 1 opt
    pull block    side 1
    set x 7       side 0 [7]
again:
    out pins 1
    jmp x-- again        [6]
