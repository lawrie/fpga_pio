`default_nettype none
module scratch (
  input         clk,
  input         penable,
  input         reset,
  input [31:0]  din,
  input         set,
  input         dec,
  output [31:0] dout
);

  reg [31:0] val;

  assign dout = val;

  always @(posedge clk) begin
    if (reset)
      val <= 0;
    else if (penable) begin
      if (set)
        val <= din;
      else if (dec)
        val <= val - 1;
    end
  end

endmodule
 
