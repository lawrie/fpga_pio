`default_nettype none
module pio (
  input         clk,
  input         reset,
  input [23:0]  div,
  input [1:0]   mindex,
  input [31:0]  din,
  input [4:0]   index,
  input [2:0]   action,
  output [31:0] dout,
  input [31:0]  gpio_in,
  output [31:0] gpio_out,
  output [31:0] gpio_dir,
  output        irq0,
  output        irq1
);

  // Shared instructions memory
  reg [15:0]  instr [0:31];

  reg         wrap = 0;
  reg         pull;
  reg         push;
  reg [3:0]   en;
  wire [4:0]  pc1, pc2, pc3, pc4;
  wire [23:0] div1, div2, div3, div4;
  wire [31:0] din1, din2, din3, din4;
  wire [31:0] dout1, dout2, dout3, dout4;

  // Configure machines  
  always @(posedge clk) begin
    if (reset) begin
    end else begin
     wrap <= 0;
     case (action)
       1: instr[index] <= din; // Set an instruction
       2: wrap <= 1;           // Set wrap
       3: pull <= 1;            // Pop a value from fifo
       4: push <= 1;           // Push a value to fifo
     endcase
    end
  end

  machine machine_1 (
    .clk(clk),
    .reset(reset),
    .en(en[0]),
    .div(div1),
    .instr(instr[pc1]),
    .pstart(index),
    .pend(index),
    .pc(pc1),
    .din(din1),
    .dout(dout1)
  );

  machine machine_2 (
    .clk(clk),
    .reset(reset),
    .en(en[1]),
    .div(div2),
    .instr(instr[pc2]),
    .pstart(index),
    .pend(index),
    .pc(pc2),
    .din(din2),
    .dout(dout2)
  );

  machine machine_3 (
    .clk(clk),
    .reset(reset),
    .en(en[2]),
    .div(div3),
    .instr(instr[pc3]),
    .pstart(index),
    .pend(index),
    .pc(pc3),
    .din(din3),
    .dout(dout3)
  );

  machine machine_4 (
    .clk(clk),
    .reset(reset),
    .en(en[3]),
    .div(div4),
    .instr(instr[pc4]),
    .pstart(index),
    .pend(index),
    .pc(pc4),
    .din(din4),
    .dout(dout4)
  );

  fifo fifo_tx_1 (
    .clk(clk),
    .reset(reset),
    .push(push),
    .pull(pull),
    .din(din),
    .dout(din1)
  );

  fifo fifo_rx_1 (
    .clk(clk),
    .reset(reset),
    .push(push),
    .pull(pull),
    .din(din),
    .dout(dout)
  );

  fifo fifo_tx_2 (
    .clk(clk),
    .reset(reset),
    .push(push),
    .pull(pull),
    .din(din),
    .dout(din2)
  );

  fifo fifo_rx_2 (
    .clk(clk),
    .reset(reset),
    .push(push),
    .pull(pull),
    .din(din),
    .dout(din)
  );

  fifo fifo_tx_3 (
    .clk(clk),
    .reset(reset),
    .push(push),
    .pull(pull),
    .din(din),
    .dout(din3)
  );

  fifo fifo_rx_3 (
    .clk(clk),
    .reset(reset),
    .push(push),
    .pull(pull),
    .din(din),
    .dout(dout)
  );

  fifo fifo_tx_4 (
    .clk(clk),
    .reset(reset),
    .push(push),
    .pull(pull),
    .din(din),
    .dout(din3)
  );

  fifo fifo_rx_4 (
    .clk(clk),
    .reset(reset),
    .push(push),
    .pull(pull),
    .din(din),
    .dout(dout)
  );

endmodule

