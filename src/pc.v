`default_nettype none
module pc (
  input        pclk,
  input        reset,
  input [4:0]  din,
  input        jmp,
  input        wrap,
  output [4:0] dout
);

  reg [4:0] index;
  reg [4:0] pend;

  assign dout = index;

  always @(posedge pclk) begin
    if (reset)
      pend <= 0;
    if (wrap)
      pend <= din;
  end

  always @(posedge pclk) begin
    if (reset)
      index <= 0;
    else if (jmp)
      index <= din;
    else if (index == pend)
      index <= 0;
    else
      index <= index + 1;
  end

endmodule
 
