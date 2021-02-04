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
  // uart program
  reg [15:0] program [0:31];
  initial begin
    program[0] = 16'b001_00000_001_00000; // wait 0 pin 0
    program[1] = 16'b111_01010_001_00111; // set x 7 [10]
    program[2] = 16'b010_00000_000_00001; // in pins 1
    program[3] = 16'b000_00110_010_00010; // jmp x-- 2 [6]
  end

  wire [5:0]  plen = 4;                // Program length 4
  wire [23:0] div = 24'h0 ;            // Clock divider 0
  wire [31:0] pin_grps = 32'h00000100; // OUT and SIDE groups both GPIO 0
  wire [4:0]  sideset_bits = 0;        // Side set bits 

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

    // Configure side-set bits
    action = 8;
    din = sideset_bits;

    repeat(2) @(posedge clk);

    // Set input pin high
    gpio_in[0] = 1;

    // Enable machine 1
    action = 6;
    din = 1;

    repeat(2) @(posedge clk);

    // Configuration done
    action = 0; 
    
    // Run for a while
    repeat(2) @(posedge clk);

    gpio_in[0] = 0;

    for(i=0;i<10;i=i+1) begin
      @(posedge clk);
    end

    gpio_in[0] = 1;

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
