# FPGA RP2040 PIO

## Introduction

This is an attempt to recreate the Raspberry Pi RP2040 PIO interface in Verilog.

It is currently incomplete, but some programs run in simulation and on open source FPGA boards.

The current supported boards are the Blackice MX and the Ulx3s.

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

Current working top level modules include: blink, hello, wd2812, exec, uart_tx.

## Assembling programs

You can assemble program using the Adafuit pioasm assembler (used by CircuitPython), by:

```sh
cd asm
./compile square.asm square.mem
```

and then move square.mem to the src/top and/or the sim directory.

The compiler is currently incomplete and so the .mem files sometimes need modification, e.g when the "'side_set opt" option is used.
