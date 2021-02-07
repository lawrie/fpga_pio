`default_nettype none
module pc (
  input        clk,
  input        penable,
  input        reset,
  input [4:0]  din,
  input        jmp,
  input [4:0]  pend,
  input        stalled,
  input [4:0]  wrap_target,
  output [4:0] dout
);

  reg [4:0] index = 0;

  assign dout = index;

  always @(posedge clk) begin
    if (reset)
      index <= 0;
    else if (penable && !stalled) begin
      if (jmp)
        index <= din;
      else
        index <= index == pend ? wrap_target : index + 1;
    end
  end

endmodule
 
