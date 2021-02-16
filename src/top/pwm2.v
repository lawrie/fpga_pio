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
  initial $readmemh("pwm.mem", program);

  reg [35:0] conf1 [0:31];
  reg [35:0] conf2 [0:31];
  wire [5:0] clen = 10; // Config length
  initial $readmemh("pwm_conf1.mem", conf1);
  initial $readmemh("pwm_conf2.mem", conf2);

  // State machine to send program to PIO and configure PIO state machines
  reg [1:0] state;
  reg [4:0] cindex;
  reg [4:0] pindex;

  reg [26:0] delay_cnt;
  reg [3:0]  val;
  reg        m2;

  wire [3:0] val_bits = delay_cnt[26:23];

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
        1: begin // Configure machine 1
             cindex <= cindex + 1;
             if (cindex == clen) begin
               state <= 2;
               action <= 0;
               mindex <= 1;
               cindex <= 0;
             end else begin
               action <= conf1[cindex][35:32];
               din <= conf1[cindex][31:0];
             end
           end
        2: begin // Configure machine 2
             cindex <= cindex + 1;
             if (cindex == clen) begin
               state <= 3;
               action <= 0;
             end else begin
               action <= conf2[cindex][35:32];
               din <= conf2[cindex][31:0];
             end
           end
        3: begin // Run state
             delay_cnt <= delay_cnt + 1;
             val  <= val_bits;
             action <= 0;
             m2 <= 0;
             // Send new value when top 4 bits change
             if (val_bits != val) begin
               mindex <= 0;
               action <= 4;  // PUSH
               din <= val_bits == 0 ? 32'hffff : val_bits - 1;
               m2 <= 1;
             end else if (m2) begin // Push to machine 2 on next cycle
               mindex <= 1;
               action <= 4;
             end
           end
      endcase
    end
  end

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
    .tx_full(tx_full),
    .rx_empty(rx_empty)
  );

  // Led and gpio output
`ifdef blackicemx
  assign led = ~gpio_out[1:0];
`else
  assign led = gpio_out[1:0];
`endif

  assign gn[3] = gpio_out[0];
  assign gn[2] = gpio_out[1];

endmodule

