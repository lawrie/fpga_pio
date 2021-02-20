`default_nettype none
module top (
  input         clk_25mhz,
  // Buttons
  input [6:0]   btn,
  // Leds
  output [7:0]  led,
  output [27:0] gn,
  output        tx
);

  // PIO registers and wires
  reg [31:0]  din;        // Data sent to PIO
  reg [4:0]   index;      // Instruction index
  reg [3:0]   action;     // Action to be done by PIO
  reg [1:0]   mindex;     // Machine index
  reg [31:0]  gpio_in;    // Input pins to PIO

  wire [31:0] gpio_out;   // Output pins from PIO
  wire [31:0] gpio_dir;   // Pin directions
  wire [31:0] dout;       // Output from PIO
  wire        irq0, irq1; // IRQ flags from PIO
  wire [3:0]  tx_full;    // Set when TX fifo is full  
  wire [3:0]  rx_empty;   // Set when RX fifo is empty

  // Power-on reset
  reg [15:0] pwr_up_reset_counter = 0;
  wire       pwr_up_reset_n = &pwr_up_reset_counter;
  wire       n_reset = pwr_up_reset_n & btn[0];
  wire       reset = ~n_reset;

  always @(posedge clk_25mhz) begin
    if (!pwr_up_reset_n)
      pwr_up_reset_counter <= pwr_up_reset_counter + 1;
  end

  // Configuration of state machines and program instructions
  reg [15:0] program [0:31];
  initial $readmemh("i2s.mem", program);

  reg [35:0] conf [0:31];
  wire [5:0] clen = 5; // Config length
  initial $readmemh("i2s_conf.mem", conf);

  reg [14:0] muindex;
  reg [31:0] music [0:32767];
  initial $readmemh("music.mem", music);

  // State machine to send program to PIO and configure PIO state machines
  reg [1:0] state;
  reg [4:0] cindex;
  reg [4:0] pindex;

  reg [2:0] delay_cnt;

  wire [31:0] sample = music[muindex];

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
             if (pindex == 31)
               state <= 1;
           end
        1: begin // Do configuration
             cindex <= cindex + 1;
             if (cindex == clen) begin
               state <= 2;
               action <= 0;
             end else begin
               action <= conf[cindex][35:32];
               din <= conf[cindex][31:0];
             end
           end
        2: begin // Run state
             action <= 0;
             delay_cnt <= delay_cnt + 1;
             if (!tx_full[0] && delay_cnt == 0) begin
               action <= 4;  // PUSH
               din <= {sample[23:16], sample[31:24], sample[7:0], sample[15:8]};
               muindex <= muindex + 1;
             end
           end
      endcase
    end
  end

  wire [3:0] pclk;

  // PIO instance 1
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
    .irq1(irq1),
    .pclk(pclk),
    .tx_full(tx_full),
    .rx_empty(rx_empty)
  );

  // Led and gpio output
  assign led = ~0;
  assign gn[3:0] = {pclk[0], gpio_out[2:0]};

endmodule

