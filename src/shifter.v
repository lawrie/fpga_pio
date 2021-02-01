`default_nettype none
module shifter (
  input         clk,
  input         penable,
  input         reset,
  input [31:0]  din,
  input [4:0]   shift,
  input         dir,
  input         set,
  input         do_shift,
  output [31:0] dout,
  output [6:0]  shift_count
);

  reg [63:0] shift_reg;
  reg [6:0]  count;

  always @(posedge clk) begin
    if (reset) begin
      shift_reg <= 0;
      count <= 0;
    end else if (penable) begin
       if (set) begin
         if (dir) shift_reg[63:32]  <= din; // For right shift
         else shift_reg[31:0] <= din;       // For left shift
       end else if (do_shift) begin
         if (dir)
           shift_reg = shift_reg >> shift;
         else
           shift_reg = shift_reg << shift;
         count <= count + shift > 32 ? 32 : count + shift;
       end
    end
  end

  assign dout = dir ? shift_reg[31:0] > (32 - shift)  : shift_reg[63:32]; // TODO correct left shift
  assign shift_count = count;

endmodule
 
