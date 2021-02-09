`timescale 1ns/100ps
module tb();

  initial begin
    $dumpfile("waves.vcd");
    $dumpvars(0, tb);
  end

  // Clock generation	
  reg clk;
  reg reset;

  initial begin
    clk = 1'b0;
  end

  // 25MHz clock
  always begin
    #20 clk = !clk;
  end

  // PIO inputs
  reg [31:0]  din;
  reg [4:0]   index;
  reg [3:0]   action;
  reg [1:0]   mindex;
  reg [31:0]  gpio_in = 0; 
  
  // PIO outputs
  wire [31:0] gpio_out; 
  wire[31:0]  gpio_dir; 
  wire [31:0] dout;
  wire [3:0]  full;
  wire [3:0]  empty;

  // Configuration
  reg [15:0] program [0:31];
  initial $readmemh("spi.mem", program);

  wire [5:0]  plen = 2;                 // Program length
  wire [23:0] div = 24'h0C80;           // Clock divider for 1MHz
  wire [31:0] pin_grps = 32'h01110900;  // SIDE grp pin 0, OUT pin 1
  wire [5:0]  sideset_bits = 6'b100001; // Side-set bits
  integer i;

  // Actions
  localparam NONE  = 0;
  localparam INSTR = 1;
  localparam PEND  = 2;
  localparam PULL  = 3;
  localparam PUSH  = 4;
  localparam GRPS  = 5;
  localparam EN    = 6;
  localparam DIV   = 7;
  localparam SIDES = 8;
  localparam IMM   = 9;
  localparam APUSH = 10;
  localparam APULL = 11;
  localparam IPINS = 12;
  localparam IDIRS = 13;
  localparam ISRT  = 14;
  localparam OSRT  = 15;

  // Task to send action to PIO
  task act (
    input [3:0]  a,
    input [31:0] d
  );
    begin
      @(negedge clk);
      action = a;
      din = d;
      @(posedge clk);
    end
  endtask

  // Configure and run the PIO program
  initial begin
    // Do reset
    reset = 1'b1;
    repeat(2) @(posedge clk);
    reset = 1'b0;

    // Set the instructions
    for(i=0;i<plen;i++) begin
      index = i;
      act(INSTR, program[i]);
    end

    // Set wrap for machine 1
    mindex = 0;
    act(PEND, plen - 1);

    // Set fractional clock divider
    act(DIV, div);
    
    // Set pin groups
    act(GRPS, pin_grps);

    // Configure side-set bits
    act(SIDES, sideset_bits);

    // Configure autopull threshold and shift direction
    act(OSRT, 6'b101000);

    // Configure autopush threshold
    act(ISRT, 8);

    // Configure auto-pull
    act(APULL, 1);

    // Configure auto-push
    act(APUSH, 1);

    // Enable machine 1
    act(EN, 1);

    // Configuration done
    act(NONE, 0);
    
    // Small gap
    repeat(2) @(posedge clk);

    gpio_in[0] = 1;

    for(i=1;i<3;i++) begin
      act(PUSH, i << 30);
      action = 0;
      // Wait for it to be sent
      repeat(500) @(posedge clk);

      // Get the result
      act(PULL, 0);
      action = 0;
    end

    $finish;
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
    .gpio_dir(gpio_dir),
    .full(full),
    .empty(empty)
  );

endmodule 
