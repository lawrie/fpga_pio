.program blink
    set pindirs 1
again:
    set pins 1 [31]  ; Drive pin high and then delay for 31 cycles
    nop [31]
    nop [31]
    nop [31]
    nop [31]
    set pins 0 [30]  ; Drive pin low
    nop [31]
    nop [31]
    nop [31]
    nop [31]
    jmp again


