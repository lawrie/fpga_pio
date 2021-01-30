`default_nettype none
module scratch (
  input         pclk,
  input         reset,
  input [31:0]  din,
  input         set,
  input         dec,
  output [31:0] dout
);

  reg [31:0] val;

  assign dout = val;

  always @(posedge pclk) begin
    if (reset)
      val <= 0;
    else if (set)
      val <= din;
    else if (dec)
      val <= val - 1;
  end

endmodule
 
