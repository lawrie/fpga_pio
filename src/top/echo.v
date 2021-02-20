`default_nettype none
module top (
  input         clk_25mhz,
  // Buttons
  input [6:0]   btn,
  // Leds
  output [7:0]  led,
  output [27:0] gn,

  input         rx,
  output        tx
);

  // PIO registers and wires
  reg [31:0]  din;        // Data sent to PIO
  reg [4:0]   index;      // Instruction index
  reg [3:0]   action;     // Action to be done by PIO
  reg [1:0]   mindex;     // Machine index
  wire [31:0]  gpio_in;    // Input pins to PIO

  wire [31:0] gpio_out;   // Output pins from PIO
  wire [31:0] gpio_dir;   // Pin directions
  wire [31:0] dout;       // Output from PIO
  wire        irq0, irq1; // IRQ flags from PIO
  wire [3:0]  tx_full;    // Set when TX fifo is full  
  wire [3:0]  rx_empty;   // Set when RX fifo is empty

  wire [4:0] offset = 4;

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
  reg [15:0] program1 [0:31];
  initial $readmemh("uart_rx.mem", program1);
  wire [4:0] plen1 = 4;

  reg [15:0] program2 [0:31];
  initial $readmemh("uart_tx.mem", program2);
  wire [4:0] plen2 = 4;

  reg [35:0] conf1 [0:31];
  initial $readmemh("rx_conf.mem", conf1);
  wire [4:0] clen1 = 5; // Config 1 length
  
  reg [35:0] conf2 [0:31];
  initial $readmemh("tx_conf2.mem", conf2);
  wire [4:0] clen2 = 6; // Config 2 length

  // State machine to send program to PIO and configure PIO state machines
  reg [2:0] state;
  reg [4:0] cindex;
  reg [4:0] pindex;

  reg [2:0] delay_cnt;
  reg rx_ready;

  reg [7:0] data;

  always @(posedge clk_25mhz) begin
    if (reset) begin
      din <= 0;
      action <= 0;
      index <= 0;
      mindex <= 0;
      state <= 0;
      cindex <= 0;
      pindex <= 0;
    end else begin
      case (state)
        0: begin // Send program 1 to pio
             if (pindex < plen1) begin
               action <= 1;
               din <= program1[pindex];
               pindex <= pindex + 1;
               index <= pindex;
             end else begin
               state <= 1;
               pindex <= 0;
               action <= 0;
             end
           end
        1: begin // Send program 2 to pio
             if (pindex < plen2) begin
               action <= 1;
               din <= program2[pindex][15:13] == 0 ? program2[pindex] + offset : program2[pindex];
               pindex <= pindex + 1;
               index <= pindex + offset;
             end else begin
               state <= 2;
               action <= 0;
               mindex <= 0;
             end
           end
        2: begin // Configure machine 1
             cindex <= cindex + 1;
             if (cindex == clen1) begin
               state <= 3;
               action <= 0;
               mindex <= 1;
               cindex <= 0;
             end else begin
               action <= conf1[cindex][35:32];
               din <= conf1[cindex][31:0];
             end
           end
        3: begin // Configure machine 2
             cindex <= cindex + 1;
             if (cindex == clen2) begin
               state <= 4;
               action <= 0;
             end else begin
               action <= conf2[cindex][35:32];
               din <= conf2[cindex][31:0];
             end
           end
        4: begin // Run state
             action <= 0;
             delay_cnt <= delay_cnt + 1;
             rx_ready <= 0;
             if (!rx_empty[0] && &delay_cnt) begin
               mindex <= 0;
               action <= 3; // Pull
               rx_ready <= 1;
             end
             if (rx_ready) begin
               mindex <= 1;
               din <= dout[31:24];
               data <= dout[31:24];
               action <= 4; // Push
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
  assign led = ~{rx_ready, rx_empty[0]};
`else
  assign led = data;
`endif

  assign tx = gpio_out[0];
  assign gpio_in[0] = rx;

endmodule

