`default_nettype none
module shifter (
  input         pclk,
  input         reset,
  input [31:0]  din,
  input [4:0]   shift,
  input         dir,
  input         set,
  output [31:0] dout
);

  reg [31:0] shift_reg;

  always @(posedge pclk) begin
    if (reset)
      shift_reg <= 0;
    else if (set)
      shift_reg <= din;
  end

  assign dout = 0;

endmodule
 
