`default_nettype none
module decoder (
  input        pclk,
  input        reset,
  input [15:0] instr,
  input [2:0]  sideset_bits,
  output [2:0] op,
  output [4:0] op1,
  output [4:0] op2,
  output [4:0] delay,
  output [4:0] side_set
);

  assign op = instr[15:13];
  assign op1 = instr[7:5];
  assign op2 = instr[4:0];
  assign delay = instr[12:8] >> sideset_bits;
  assign side_set = instr[12:8] << (5 - sideset_bits) >> (5 - sideset_bits);

endmodule
 
