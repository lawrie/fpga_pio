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

  wire [4:0] offset = 4;

  // Configuration
  reg [15:0] program [0:31];
  initial $readmemh("uart_tx.mem", program);

  wire [5:0]  plen = 4;                // Program length
  wire [23:0] div = 24'h0200;          // Clock divider
  wire [31:0] pin_grps = 32'h40100000; // OUT and SIDE grps pin 0
  wire [31:0] exec_ctrl = 32'h40003000; // Wrap top and sideset enable bit

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
      index = offset + i;
      act(INSTR, program[i][15:13] == 0 ? program[i] + offset : program[i]);
    end

    // Set wrap for machine 1
    mindex = 0;
    act(PEND, exec_ctrl + (offset << 12) + (offset << 7)); // Adjust wrap and wrap_target

    // Set fractional clock divider
    act(DIV, div);
    
    // Set pin groups
    act(GRPS, pin_grps);

    // Configure shift out direction
    act(SHIFT, 32'h00080000);

    // If offset is not zero, set PC to offset
    if (offset > 0) begin
      act(IMM, offset);
    end

    // Enable machine 1
    act(EN, 1);

    // Configuration done
    act(NONE, 0);
    
    // Small gap
    repeat(2) @(posedge clk);

    // Send data
    for(i=0;i<10;i++) begin
      // Send numeric character
      act(PUSH, 32'h30 + i);
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

