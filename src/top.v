`default_nettype none
module top (
  input         clk_25mhz,
  // Buttons
  input [6:0]   btn,
  // Leds
  output [7:0]  led
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

  wire reset = ~btn[0];

  // Configuration
  // uart program
  // Configuration
  reg [15:0] program [0:31];
  initial begin // square
    program[0] = 16'b111_00000_100_00001; // set pindirs 1
    program[1] = 16'b111_00001_000_00001; // set pins 1 [1]
    program[2] = 16'b111_00000_000_00000; // set pins 0 
    program[3] = 16'b000_00000_000_00001; // jmp 1
  end

  //initial begin // uart
  //  program[0] = 16'b100_11000_101_00000; // pull side 1
  //  program[1] = 16'b111_10111_001_00111; // set x 7, side 0 [7]
  //  program[2] = 16'b011_00000_000_00001; // out pins 1
  // program[3] = 16'b000_00110_010_00010; // jmp x-- 2 [6]
  //end

  wire [5:0]  plen = 4; // Program length

  reg [35:0] config [0:31];
  initial begin
    config[0] = 36'h200000003; // Set wrap
    config[1] = 36'h700000280; // Set divider 2.5
    config[2] = 36'h500000001; // Set pin groups
    config[3] = 36'h800000000; // Set sideset bits
    config[4] = 36'h600000001; // Enable machine
  end

  wire [5:0] clen = 5; // Config length

  reg [1:0] state;
  reg [4:0] cindex;

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
    end else begin
      case (state)
        0: begin // Send program to pio
             action <= 1;
             din <= program[index];
             index <= index + 1;
             if (index == plen - 1) begin
               state <= 1;
               action <= 0;
               cindex <= 0;
             end
           end
        1: begin // Do configuration
             action <= config[cindex][35:32];
             din <= config[cindex][31:0];
             mindex <= 0;
             cindex <= cindex + 1;
             if (cindex == clen - 1) begin
               state <= 2;
               action <= 0;
             end
           end
        2: begin // Run state
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

endmodule

