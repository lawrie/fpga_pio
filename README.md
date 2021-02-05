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
make clean sim TB=uart_tx
```

## Synthesis

To run the top.v Verilog file on the Blackice MX board, do:

```sh
cd blackicemx
make prog
```

For the Ulxs3 board use the ulx3s directory.

The current program flashes the red led approximately once per second.
