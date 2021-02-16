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
  wire [3:0]  tx_full;
  wire [3:0]  rx_empty;

  // Configuration
  reg [15:0] program [0:31];
  initial $readmemh("pwm.mem", program);

  wire [5:0]  plen = 7;                 // Program length
  wire [23:0] div = 24'h0280;           // Clock divider
  wire [31:0] pin_grps = 32'h40000000;  // SIDE grp pin 0
  wire [31:0] exec_ctrl = 32'h40006000; // Wrap top and sideset enable bit

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
  localparam SHIFT = 10;

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
    act(PEND, exec_ctrl);

    // Set fractional clock divider
    act(DIV, div);
    
    // Set pin groups
    act(GRPS, pin_grps);

    // Push the period
    act(PUSH, 10);
    repeat(2) @(posedge clk);
    action = 0;

    // Send a PULL
    act(IMM, 16'b100_00000_100_00000);
    repeat(2) @(posedge clk);
    action = 0;

    // Send a MOV ISR OSR
    act(IMM, 16'b101_00000_110_00111);
    repeat(2) @(posedge clk);
    action = 0;

    // Enable machine 1
    act(EN, 1);

    // Configuration done
    act(NONE, 0);
    
    // Small gap
    repeat(2) @(posedge clk);

    for(i=1;i<3;i++) begin
      act(PUSH, i << 1);
      action = 0;

      // Wait for it to be sent
      repeat(180) @(posedge clk);
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
    .tx_full(tx_full),
    .rx_empty(rx_empty)
  );

endmodule 

