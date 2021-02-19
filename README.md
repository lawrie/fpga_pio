# FPGA RP2040 PIO

## Introduction

This is an attempt to recreate the Raspberry Pi RP2040 PIO interface in Verilog.

It is currently incomplete, but some programs run in simulation and on open source FPGA boards.

The current supported boards are the Blackice MX and the Ulx3s.

The current method of configuring and controlling PIO from a top-level module is different from that used on the RP2040 chip, and will probably be changed for closer compatibility.

For use by a SoC, e.g. a RISC-V SoC such as SaxonSoc, the appropriate peripheral bus interface would need to be added.

For use from a host processor, such as one running micropython, an SPI read/write memory interface could be added. This would be a lot slower than a bus interface but speed is not usually an issue for configuration and control. There are usually too few pins between a host processor and the fpga to implement a 32-bit (or even an 8-bit) bus interface.

## Simulation

To run a program in simulation, clone the repository and do:

```sh
cd fpga_pio/sim
make sim
```

That runs the tb.v testbench. You can see the results by opening waves.vcd using gtkwave.

You can run the other test programs in the sim directory, such as uart_tx.v, by:

```sh
make sim TB=uart_tx
```

## Synthesis

To run the top.v Verilog file on the Blackice MX board, do:

```sh
cd blackicemx
make prog
```

For the Ulxs3 board use the ulx3s directory.

The current program flashes the red led approximately once per second.

You can select a different top-level module by, for example:

```sh
make clean prog TOP=hello
```

Current working top level modules include: blink, hello, wds812, exec, uart_tx.

## Assembling programs

You can assemble program using the Adafuit pioasm assembler (used by CircuitPython), by:

```sh
cd asm
./compile square.asm square.mem
```

and then move square.mem to the src/top and/or the sim directory.

The compiler is currently incomplete and so the .mem files sometimes need modification, e.g when the "'side_set opt" option is used.

## Examples

### Blink

```
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
```

This blinks every 320 cycles. so with a maximum clock divider of 64K -1 (0xFFFF), and a 25MHz FPGA clock, it blinks approximately every 1.2 seconds.

### Hello

```
.program uart_tx
.side_set 1 opt
    pull block    side 1
    set x 7       side 0 [7]
again:
    out pins 1
    jmp x-- again        [6]
```

This example outputs a message repeatedly on the console.

### Exec

The exec examples needs no PIO program as it executes a SET PINS instruction immediately. The machine does not need to be enabled.
The top/exec.v Verilog module uses immediate execution to blink the led approximately once per second.

### Pwm

```
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
```

The pwm example set the led off and then increases its brightness, repeatedly.

### Neopixels

```
.program ws2812
.side_set 1
.wrap_target
bitloop:
  out x 1        side 0 [1]; Side-set still takes place when instruction stalls
  jmp !x do_zero side 1 [1]; Branch on the bit we shifted out. Positive pulse
do_one:
  jmp  bitloop   side 1 [1]; Continue driving high, for a long pulse
do_zero:
  nop            side 0
```

![ws2812 example](https://raw.githubusercontent.com/lawrie/lawrie.github.io/master/images/ws2812.jpg)

### Stepper motor

This example shows driving a stepper motor with PIO. 

You set the direction by pushing the required phase patterns as a set of 8 4-bit values, and then you push the required number of half steps.

To start again with a new set of steps, you execute an immediate jump to the start of the program.

```
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
```

Here is is driving a stepper motor from a Blackice MX:

![blackice mx stepper](https://github.com/lawrie/lawrie.github.io/blob/master/images/stepper_mx.jpg)
