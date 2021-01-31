`default_nettype none
module pc (
  input        clk,
  input        penable,
  input        reset,
  input [4:0]  din,
  input        jmp,
  input [4:0]  pend,
  input        stalled,
  output [4:0] dout
);

  reg [4:0] index = 0;

  assign dout = index;

  always @(posedge clk) begin
    if (reset)
      index <= 0;
    else if (penable) begin
      if (jmp)
        index <= din;
      else if (!stalled)
        index <= index == pend ? 0 : index + 1;
    end
  end

endmodule
 
