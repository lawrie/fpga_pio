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

  reg [31:0]  din;
  reg [4:0]   index;
  reg [3:0]   action;
  reg [1:0]   mindex;
  reg [31:0]  gpio_in = 0; 
  
  wire [31:0] gpio_out; 
  wire[31:0]  gpio_dir; 
  wire [31:0] dout;

  // Configuration
  reg [15:0] program [0:31];
  initial begin
    program[0] = 16'b111_00000_100_00001; // set pindirs 1
    program[1] = 16'b111_00001_000_00001; // set pins 1 [1]
    program[2] = 16'b111_00000_000_00000; // set pins 0 
    program[3] = 16'b000_00000_000_00001; // jmp 1
  end

  wire [5:0] plen = 4;          // Program length 4
  wire [23:0] div = 24'h280;    // Clock divider 2.5
  wire [31:0] pin_grps = 32'h1; // SET group in pin 0

  integer i;

  initial begin
    reset = 1'b1;
    repeat(2) @(posedge clk) ;
    reset = 1'b0;

    // Set the instructions
    action = 1;

    for(i=0;i<plen;i++) begin
      index = i;
      din = program[i];

      repeat(2) @(posedge clk);
    end

    // Set wrap for machine 1
    mindex = 0;
    action = 2;
    din = plen - 1;

    repeat(2) @(posedge clk);

    // Set fractional clock divider
    action = 7;
    din  = div;

    repeat(2) @(posedge clk);

    // Set pin groups
    action = 5;
    din  = pin_grps;

    repeat(2) @(posedge clk);

    // Enable machine 1
    action = 6;
    din = 1;

    repeat(2) @(posedge clk);

    // Configuration done
    action = 0; 
    
    // Run for a while
    repeat(100) @(posedge clk);

    $finish;
  end

  always begin
    #1 clk = !clk;
  end

  pio pio_1 (
    .clk(clk),
    .reset(reset),
    .action(action),
    .index(index),
    .mindex(mindex),
    .din(din),
    .dout(dout),
    .gpio_in(gpio_in),
    .gpio_out(gpio_out),
    .gpio_dir(gpio_dir)
  );

endmodule 
