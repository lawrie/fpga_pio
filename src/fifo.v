// SPDX-FileCopyrightText: 2022 Lawrie Griffiths
// SPDX-License-Identifier: BSD-2-Clause

`default_nettype none
module fifo (
  input             clk,
  input             reset,
  input             push,
  input             pull,
  input [31:0]      din,
  output [31:0]     dout,
  output            empty,
  output            full,
  output [2:0]      level
);

  reg [31:0] arr [0:3];
  reg [1:0]  first;
  reg [1:0]  next;
  reg [2:0]  count;

  wire do_pull = pull && !empty;
  wire do_push = push && !full;

  always @(posedge clk) begin
    if (reset) begin
      first <= 0;
      next <= 0;
      count <= 0;
    end else begin
      if (do_push) begin
        next <= next + 1;
        arr[next] <= din;
        if (!do_pull) count <= count + 1;
      end
      if (do_pull) begin
        first <= first + 1;
        if (!do_push) count <= count - 1;
      end
    end
  end

  assign empty = count == 0;
  assign full = count == 4;
  assign dout = arr[first];
  assign level = count;

endmodule
