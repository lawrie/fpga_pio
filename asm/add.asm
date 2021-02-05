.program add
    pull block
    mov x ~osr
    pull block
    mov y osr
    jmp test
incr:
    jmp x-- test
test:
    jmp y-- incr
    mv isr ~x
    push

