`default_nettype none
module shifter (
  input         clk,
  input         penable,
  input         reset,
  input         stalled,
  input [31:0]  din,
  input [4:0]   shift,
  input         dir,
  input         set,
  input         do_shift,
  input [5:0]   bit_count,
  output [31:0] dout,
  output [5:0]  shift_count
);

  reg [63:0] shift_reg;
  reg [6:0]  count;
  wire [63:0] new_shift = dir ? shift_reg >> shift : shift_reg << shift;

  always @(posedge clk) begin
    if (reset) begin
      shift_reg <= 0;
      count <= 32;  // Empty
    end else if (penable && !stalled) begin
       if (set) begin
         if (dir) shift_reg <= {din, 32'b0}; // For right shift
         else shift_reg <= {32'b0, din};     // For left shift
         count <= bit_count;
       end else if (do_shift) begin
         shift_reg <= new_shift;
         count <= count + shift > 32 ? 32 : count + shift;
       end
    end
  end

  assign dout = dir ? (new_shift[31:0] >> (32 - shift))  : ((new_shift[63:32] << (32 - shift)) >> (32-shift));
  assign shift_count = count;

endmodule
 
