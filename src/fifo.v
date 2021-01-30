`default_nettype none
module fifo (
  input             clk,
  input             reset,
  input             push,
  input             pull,
  input [31:0]      din,
  output reg [31:0] dout
);

  reg [31:0] arr [0:3];
  reg [1:0]  first;
  reg [1:0]  last;

  always @(posedge clk) begin
    if (reset) begin
      first <= 0;
      last <= 0;
    end else begin
      if (push) begin
        last <= last + 1;
        arr[last] <= din;
      end else if (pull) begin
        dout <= arr[first];
        first <= first + 1;
      end
    end
  end

endmodule

