`default_nettype none
module top (
  input         clk_25mhz,
  // Buttons
  input [6:0]   btn,
`ifdef lcd_diag
  // SPI display
  output        oled_csn,
  output        oled_clk,
  output        oled_mosi,
  output        oled_dc,
  output        oled_resn,
`endif
  // Leds
  output reg [7:0]  led,
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

  reg [7:0] data;

  // Power-on reset
  reg [15:0] pwr_up_reset_counter = 0;
  wire       pwr_up_reset_n = &pwr_up_reset_counter;
  wire       n_reset = pwr_up_reset_n & btn[0];
  wire       reset = ~n_reset;

  assign gpio_in = {31'b0, rx};

  always @(posedge clk_25mhz) begin
    if (!pwr_up_reset_n)
      pwr_up_reset_counter <= pwr_up_reset_counter + 1;
  end

`ifdef lcd_diag
  // ===============================================================
  // System Clock generation
  // ===============================================================
  wire clk_sdram_locked;
  wire [3:0] clocks;
  ecp5pll
  #(
      .in_hz( 25*1000000),
    .out0_hz(125*1000000),
    .out1_hz( 25*1000000),
    .out2_hz(100*1000000),                // SDRAM core
    .out3_hz(100*1000000), .out3_deg(180) // SDRAM chip 45-330:ok 0-30:not
  )
  ecp5pll_inst
  (
    .clk_i(clk_25mhz),
    .clk_o(clocks),
    .locked(clk_sdram_locked)
  );
  wire clk_hdmi  = clocks[0];
  wire clk_vga   = clocks[1];
  wire clk_cpu  = clocks[1];
  wire clk_sdram = clocks[2];
  wire sdram_clk = clocks[3]; // phase shifted for chip
`endif

  // Configuration of state machines and program instructions
  reg [15:0] program [0:31];
  initial $readmemh("uart_rx.mem", program);

  reg [35:0] conf [0:31];
  wire [5:0] clen = 5; // Config length
  initial $readmemh("rx_conf.mem", conf);

  // State machine to send program to PIO and configure PIO state machines
  reg [1:0] state;
  reg [4:0] cindex;
  reg [4:0] pindex;
  reg [1:0] delay_cnt;

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
             if (!rx_empty[0] && &delay_cnt) begin
                action <= 3; // Pull
             end
             data <= dout[31:24];
           end
      endcase
    end
  end

  wire [127:0] diag;

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
  always @(posedge clk_25mhz) led <= data;
  assign tx = gpio_out[0];

`ifdef lcd_diag
  localparam c_lcd_hex = 1;

  reg [6:0]     r_btn_joy;
  always @(posedge clk_25mhz) r_btn_joy <= btn;

  // ===============================================================
  // LCD diagnostics
  // ===============================================================
  generate
  if(c_lcd_hex) begin
  // SPI DISPLAY
  reg [127:0] r_display;
  // HEX decoder does printf("%16X\n%16X\n", r_display[63:0], r_display[127:64]);
  always @(posedge clk_25mhz)
    r_display <= diag;

  parameter c_color_bits = 16;
  wire [7:0] x;
  wire [7:0] y;
  wire [c_color_bits-1:0] color;
  hex_decoder_v
  #(
    .c_data_len(128),
    .c_row_bits(4),
    .c_grid_6x8(1), // NOTE: TRELLIS needs -abc9 option to compile
    .c_font_file("hex_font.mem"),
    .c_color_bits(c_color_bits)
  )
  hex_decoder_v_inst
  (
    .clk(clk_hdmi),
    .data(r_display),
    .x(x[7:1]),
    .y(y[7:1]),
    .color(color)
  );

  wire next_pixel;
  reg [c_color_bits-1:0] r_color;
  wire w_oled_csn;

  always @(posedge clk_hdmi)
    if(next_pixel) r_color <= color;

  lcd_video #(
    .c_clk_mhz(125),
    .c_init_file("st7789_linit_xflip.mem"),
    .c_clk_phase(0),
    .c_clk_polarity(1),
    .c_init_size(38)
  ) lcd_video_inst (
    .clk(clk_hdmi),
    .reset(r_btn_joy[5]),
    .x(x),
    .y(y),
    .next_pixel(next_pixel),
    .color(r_color),
    .spi_clk(oled_clk),
    .spi_mosi(oled_mosi),
    .spi_dc(oled_dc),
    .spi_resn(oled_resn),
    .spi_csn(w_oled_csn)
  );

  //assign oled_csn = w_oled_csn; // 8-pin ST7789: oled_csn is connected to CSn
  assign oled_csn = 1; // 7-pin ST7789: oled_csn is connected to BLK (backlight enable pin)
  end
  endgenerate
`endif

endmodule

