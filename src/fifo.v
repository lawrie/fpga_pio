`default_nettype none
module fifo (
  input             clk,
  input             reset,
  input             push,
  input             pull,
  input [31:0]      din,
  output reg [31:0] dout,
  output            empty,
  output            full
);

  reg [31:0] arr [0:3];
  reg [1:0]  first;
  reg [1:0]  last;
  reg [2:0]  count;

  always @(posedge clk) begin
    if (reset) begin
      first <= 0;
      last <= 0;
      count = 0;
      dout <= 0;
    end else begin
      if (push && !full) begin
        last <= last + 1;
        arr[last] <= din;
        count <= count + 1;
      end else if (pull && !empty) begin
        dout <= arr[first];
        first <= first + 1;
        count <= count - 1;
      end
    end
  end

  assign empty = count == 0;
  assign full = count == 4;

endmodule

