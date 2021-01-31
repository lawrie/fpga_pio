`default_nettype none
module pio (
  input         clk,
  input         reset,
  input [1:0]   mindex,
  input [31:0]  din,
  input [4:0]   index,
  input [3:0]   action,
  output [31:0] dout,
  input [31:0]  gpio_in,
  output [31:0] gpio_out,
  output [31:0] gpio_dir,
  output        irq0,
  output        irq1
);

  // Shared instructions memory
  reg [15:0]  instr [0:31];

  reg         wrap;
  reg         pull;
  reg         push;
  reg         imm;
  reg [3:0]   en;
  reg [3:0]   jmp_pin;
  reg [2:0]   sideset_bits_1, sideset_bits_2, sideset_bits_3, sideset_bits_4;
  
  reg [4:0]   pstart [0:3];
  reg [4:0]   pend [0:3];
  reg [23:0]  div [0:3];
  reg [4:0]   pins_out_base [0:3];
  reg [2:0]   pins_out_count [0:3];
  reg [4:0]   pins_set_base [0:3];
  reg [2:0]   pins_set_count [0:3];

  wire [4:0]  pc1, pc2, pc3, pc4;
  wire [31:0] din1, din2, din3, din4;
  wire [31:0] dout1, dout2, dout3, dout4;

  integer i;

  // Configure machines  
  always @(posedge clk) begin
    if (reset) begin
      sideset_bits_1 <= 0;
      sideset_bits_2 <= 0;
      sideset_bits_3 <= 0;
      sideset_bits_4 <= 0;
      en <= 0;
      jmp_pin <= 0;
      for(i=0;i<4;i++) begin
        div[i] <= 2;
        pend[i] <= 0;
        pins_out_count[i] <= 0;
        pins_out_base[i] <= 0;
        pins_set_count[i] <= 1;
        pins_set_base[i] <= 0;
      end
    end else begin
     wrap <= 0;
     pull <= 0;
     push <= 0;
     imm <= 0;
     case (action)
       1: instr[index] <= din[15:0]; // Set an instruction
       2: begin                      // Configure pend
            pend[mindex] <= index; 
          end 
       3: pull <= 1;                 // Pop a value from fifo
       4: push <= 1;                 // Push a value to fifo
       5: begin                      // Configure pins 
          end
       6: en <= din[3:0];            // Enable machines
       7: div[mindex] <= din[23:0];  // Configure clock dividers
       8: begin end                  // Configure side-set bits
       9: imm <= 1;                  // Immediate instruction
     endcase
    end
  end

  machine machine_1 (
    .clk(clk),
    .reset(reset),
    .en(en[0]),
    .jmp_pin(jmp_pin[0]),
    .input_pins(gpio_in),
    .output_pins(gpio_out),
    .pin_directions(gpio_dir),
    .sideset_bits(sideset_bits_1),
    .div(div[0]),
    .instr(imm ? din[15:0] : instr[pc1]),
    .imm(imm),
    .pstart(pstart[0]),
    .pend(pend[0]),
    .pins_out_base(pins_out_base[0]),
    .pins_out_count(pins_out_count[0]),
    .pins_set_base(pins_set_base[0]),
    .pins_set_count(pins_set_count[0]),
    .pc(pc1),
    .din(din1),
    .dout(dout1)
  );

  machine machine_2 (
    .clk(clk),
    .reset(reset),
    .en(en[1]),
    .jmp_pin(jmp_pin[1]),
    .input_pins(gpio_in),
    .output_pins(gpio_out),
    .pin_directions(gpio_dir),
    .sideset_bits(sideset_bits_2),
    .div(div[1]),
    .instr(instr[pc2]),
    .pstart(pstart[1]),
    .pend(pend[1]),
    .pc(pc2),
    .din(din2),
    .dout(dout2)
  );

  machine machine_3 (
    .clk(clk),
    .reset(reset),
    .en(en[2]),
    .jmp_pin(jmp_pin[2]),
    .input_pins(gpio_in),
    .output_pins(gpio_out),
    .pin_directions(gpio_dir),
    .sideset_bits(sideset_bits_3),
    .div(div[2]),
    .instr(instr[pc3]),
    .pstart(pstart[2]),
    .pend(pend[2]),
    .pc(pc3),
    .din(din3),
    .dout(dout3)
  );

  machine machine_4 (
    .clk(clk),
    .reset(reset),
    .en(en[3]),
    .jmp_pin(jmp_pin[3]),
    .input_pins(gpio_in),
    .output_pins(gpio_out),
    .pin_directions(gpio_dir),
    .sideset_bits(sideset_bits_4),
    .div(div[3]),
    .instr(instr[pc4]),
    .pstart(pstart[3]),
    .pend(pend[3]),
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
    .dout(din3)
  );

  fifo fifo_tx_3 (
    .clk(clk),
    .reset(reset),
    .push(push),
    .pull(pull),
    .din(din),
    .dout(dout)
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

