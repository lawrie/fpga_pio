`default_nettype none
module pc (
  input        pclk,
  input        reset,
  input [4:0]  din,
  input        jmp,
  input [4:0]  pend,
  input        stalled,
  output [4:0] dout
);

  reg [4:0] index = 0;

  assign dout = index;

  always @(posedge pclk) begin
    if (reset)
      index <= 0;
    else if (jmp)
      index <= din;
    else if (!stalled)
      index <= index == pend ? 0 : index + 1;
  end

endmodule
 
