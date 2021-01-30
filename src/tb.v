`timescale 1ns/100ps
module tb();

  initial begin
    $dumpfile("waves.vcd");
    $dumpvars(0, tb);
  end
	
  reg clk;
  reg reset;

  initial begin
    clk = 1'b0;
  end

  initial begin
    reset = 1'b1;
    repeat(2) @(posedge clk) ;
    reset = 1'b0;

    repeat(100) @(posedge clk);

    $finish;
  end

  always begin
    #1 clk = !clk;
  end

  reg [31:0]  din = 0;
  wire [31:0] dout;
  reg [4:0]   index = 0;
  reg [23:0]  div = 2;
  reg [2:0]   action = 0;

  pio pio_inst (
    .clk(clk),
    .reset(reset),
    .div(div),
    .action(action),
    .index(index),
    .din(din),
    .dout(dout)
  );

endmodule 
