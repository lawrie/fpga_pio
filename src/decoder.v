// SPDX-FileCopyrightText: 2022 Lawrie Griffiths
// SPDX-License-Identifier: BSD-2-Clause

`default_nettype none
module decoder (
  input [15:0] instr,
  input [2:0]  sideset_bits,
  input        sideset_enable_bit,
  output [2:0] op,
  output [2:0] op1,
  output [4:0] op2,
  output [4:0] delay,
  output [4:0] side_set,
  output       sideset_enabled
);

  wire [2:0] delay_bits = 5 - sideset_bits;

  assign op = instr[15:13];
  assign op1 = instr[7:5];
  assign op2 = instr[4:0];
  assign delay = (instr[12:8] << sideset_bits) >> sideset_bits;
  assign side_set = instr[12:8] << sideset_enable_bit >> sideset_enable_bit + delay_bits;
  assign sideset_enabled = sideset_enable_bit ? instr[12] : 1;

endmodule
 
