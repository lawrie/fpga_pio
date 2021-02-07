`default_nettype none
module divider (
  input         clk,
  input         reset,
  input [23:0]  div,
  output        penable
);

  reg [23:0] div_counter;
  reg        pen;
  reg        old_pen;

  always @(posedge clk) begin
    if (reset) begin
      div_counter <= 0;
      pen <= 1;
    end else begin
      old_pen <= pen;
      if (div < 23'h200) // normal clock if divider less than 2
        pen <= 1;
      else begin
        div_counter <= div_counter + 256;
        if (div_counter >= div - 256)
          div_counter <= div_counter - (div - 256);
        pen <= div_counter < (div >> 1);
      end
    end
  end

  assign penable = div < 24'h200 || (pen & ~old_pen);

endmodule

