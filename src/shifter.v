`default_nettype none
module shifter (
  input         clk,
  input         penable,
  input         reset,
  input [31:0]  din,
  input [4:0]   shift,
  input         dir,
  input         set,
  output [31:0] dout
);

  reg [31:0] shift_reg;

  always @(posedge clk) begin
    if (reset)
      shift_reg <= 0;
    else if (penable) begin
       if (set)
         shift_reg <= din;
    end
  end

  assign dout = 0;

endmodule
 
