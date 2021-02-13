.program ws2812
.side_set 1
.wrap_target
bitloop:
  out x 1        side 0 [2]; Side-set still takes place when instruction stalls
  jmp !x do_zero side 1 [1]; Branch on the bit we shifted out. Positive pulse
do_one:
  jmp  bitloop   side 1 [4]; Continue driving high, for a long pulse
do_zero:
  nop            side 0 [4]

