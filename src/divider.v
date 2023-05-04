// SPDX-FileCopyrightText: 2022 Lawrie Griffiths
// SPDX-License-Identifier: BSD-2-Clause

`default_nettype none
module divider (
  input        clk,
  input        reset,
  input [23:0] div,
  input        use_divider,
  output       penable,
  output       pclk
);
  wire [15:0] div_int;
  wire [7:0] div_frac;
  assign div_int = div[23:8];
  assign div_frac = div[7:0];
 
  wire not_zero_div;
  wire divint_1;
  assign not_zero_div = !((div_int == 0) && (div_frac == 0));
  assign divint_1 = (div_int == 16'd1);

  reg [23:0] div_counter;
  reg pen;
  reg old_pen;

  assign div = {div_int, div_frac};
  always @(posedge clk) begin
    if (reset) begin
      div_counter <= 0;
      pen <= 1;
      old_pen <= 0;
    end else begin
      if (not_zero_div) begin
        old_pen <= pen;
        div_counter <= div_counter + 256;
        if (div_counter >= div - 256)
          div_counter <= div_counter - (div - 256);
        pen <= div_counter < (div >> 1);
      end
    end
  end

  assign penable = ((pen & ~old_pen) || !not_zero_div) ^ divint_1;
endmodule
