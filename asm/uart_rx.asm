.program uart_rx
    wait 0 pin 0
    set x 7       [10]
again:
    in pins 1
    jmp x-- again [6]

