// SPDX-FileCopyrightText: 2022 Lawrie Griffiths
// SPDX-License-Identifier: BSD-2-Clause

`default_nettype none
module divider (
  input         clk,
  input         reset,
  input [23:0]  div,
  input         use_divider,
  output        penable,
  output        pclk
);

  reg [23:0] div_counter;
  reg        pen;
  reg        old_pen;

  always @(posedge clk) begin
    if (reset) begin
      div_counter <= 0;
      pen <= 1;
      old_pen <= 0;
    end else begin
      if (use_divider) begin
        old_pen <= pen;
        div_counter <= div_counter + 256;
        if (div_counter >= div - 256)
          div_counter <= div_counter - (div - 256);
        pen <= div_counter < (div >> 1);
      end
    end
  end

  assign penable = pen & ~old_pen;
  assign pclk = pen;

endmodule
