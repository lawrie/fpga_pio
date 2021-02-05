`default_nettype none
module top (
  input         clk_25mhz,
  // Buttons
  input [6:0]   btn,
  // Leds
  output [7:0]  led,
  output [27:0] gn
);

  reg [31:0]  din;
  reg [4:0]   index;
  reg [3:0]   action;
  reg [1:0]   mindex;
  reg [31:0]  gpio_in;

  wire [31:0] gpio_out;
  wire [31:0] gpio_dir;
  wire [31:0] dout;
  wire        irq0, irq1;

  reg [15:0] pwr_up_reset_counter = 0;
  wire      pwr_up_reset_n = &pwr_up_reset_counter;
  wire      n_reset = pwr_up_reset_n & btn[0];
  wire      reset = ~n_reset;

  always @(posedge clk_25mhz) begin
    if (!pwr_up_reset_n)
      pwr_up_reset_counter <= pwr_up_reset_counter + 1;
  end

  // Configuration
  reg [15:0] program [0:31];
  initial begin // square
    program[0] = 16'b111_00000_100_00001; // set pindirs 1
    program[1] = 16'b111_11111_000_00001; // set pins 1 [31]
    program[2] = 16'b101_11111_010_00010; // nop [31]
    program[3] = 16'b101_11111_010_00010; // nop [31]
    program[4] = 16'b101_11111_010_00010; // nop [31]
    program[5] = 16'b101_11111_010_00010; // nop [31]
    program[6] = 16'b111_11110_000_00000; // set pins 0 [30] 
    program[7] = 16'b101_11111_010_00010; // nop [31]
    program[8] = 16'b101_11111_010_00010; // nop [31]
    program[9] = 16'b101_11111_010_00010; // nop [31]
    program[10] = 16'b101_11111_010_00010; // nop [31]
    program[11] = 16'b000_00000_000_00001; // jmp 1
  end

  //initial begin // uart
  //  program[0] = 16'b100_11000_101_00000; // pull side 1
  //  program[1] = 16'b111_10111_001_00111; // set x 7, side 0 [7]
  //  program[2] = 16'b011_00000_000_00001; // out pins 1
  // program[3] = 16'b000_00110_010_00010; // jmp x-- 2 [6]
  //end

  wire [5:0]  plen = 12; // Program length

  reg [35:0] conf [0:31];
  initial begin
    conf[0] = 36'h20000000c; // Set wrap
    conf[1] = 36'h700ffff00; // Set divider
    conf[2] = 36'h500000001; // Set pin groups
    conf[3] = 36'h800000000; // Set sideset bits
    conf[4] = 36'h600000001; // Enable machine
  end

  wire [5:0] clen = 5; // Config length

  reg [1:0] state;
  reg [4:0] cindex;
  reg [4:0] pindex;

  // State machine to send program to PIO and configure PIO state machines
  always @(posedge clk_25mhz) begin
    if (reset) begin
      din <= 0;
      action <= 0;
      index <= 0;
      mindex <= 0;
      gpio_in <= 0;
      state <= 0;
      cindex <= 0;
      pindex <= 0;
    end else begin
      case (state)
        0: begin // Send program to pio
             action <= 1;
             din <= program[pindex];
             pindex <= pindex + 1;
             index <= pindex;
             if (pindex == plen - 1)
               state <= 1;
           end
        1: begin // Do configuration
             action <= conf[cindex][35:32];
             din <= conf[cindex][31:0];
             cindex <= cindex + 1;
             if (cindex == clen - 1)
               state <= 2;
           end
        2: begin // Run state
             action <= 0;
           end
      endcase
    end
  end

  pio pio_1 (
    .clk(clk_25mhz),
    .reset(reset),
    .mindex(mindex),
    .din(din),
    .index(index),
    .action(action),
    .dout(dout),
    .gpio_in(gpio_in),
    .gpio_out(gpio_out),
    .gpio_dir(gpio_dir),
    .irq0(irq0),
    .irq1(irq1)
  );

  assign led = {reset, gpio_out[0]};
  assign gn[0] = gpio_out[0];

endmodule

