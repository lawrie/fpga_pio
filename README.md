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

Current working top level modules include: blink, hello, wd2812, exec, uart_tx.

## Assembling programs

You can assemble program using the Adafuit pioasm assembler (used by CircuitPython), by:

```sh
cd asm
./compile square.asm square.mem
```

and then move square.mem to the src/top and/or the sim directory.

The compiler is currently incomplete and so the .mem files sometimes need modification, e.g when the "'side_set opt" option is used.
