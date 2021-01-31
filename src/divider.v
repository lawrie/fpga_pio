`default_nettype none
module divider (
  input         clk,
  input         reset,
  input [23:0]  div,
  output reg    pclk
);

  reg [31:0] div_counter;
  always @(posedge clk) begin
    if (reset) begin
      div_counter <= 0;
      pclk <= 0;
    end else begin
      div_counter <= div_counter + 256;
      if (div_counter >= div -1)
        div_counter <= 0;
      pclk <= div_counter < (div >> 1);
    end
  end
endmodule
 
