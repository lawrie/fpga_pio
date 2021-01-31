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
  
  reg [4:0]   pstart [0:3];
  reg [4:0]   pend [0:3];
  reg [23:0]  div [0:3];
  reg [4:0]   pins_out_base [0:3];
  reg [2:0]   pins_out_count [0:3];
  reg [4:0]   pins_set_base [0:3];
  reg [2:0]   pins_set_count [0:3];
  wire [31:0] output_pins [0:3];
  wire [31:0] pin_directions [0:3];
  reg [2:0]   sideset_bits [0:3];

  wire [4:0]  pc1, pc2, pc3, pc4;
  wire [31:0] din1, din2, din3, din4;
  wire [31:0] dout1, dout2, dout3, dout4;

  assign gpio_out = output_pins[0]; // TODO: Combine outputs from machines
  assign gpio_dir = pin_directions[0];

  integer i;

  // Configure machines  
  always @(posedge clk) begin
    if (reset) begin
      en <= 0;
      jmp_pin <= 0;
      for(i=0;i<4;i++) begin
        div[i] <= 0; // no clock divider
        pend[i] <= 0;
        pstart[i] <= 0;
        pins_out_count[i] <= 0;
        pins_out_base[i] <= 0;
        pins_set_count[i] <= 0;
        pins_set_base[i] <= 0;
        sideset_bits[i] <= 0;
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
       5: begin                      // Configure pin groups
            pins_set_count[mindex] <= din[2:0];
            pins_set_base[mindex]  <= din[7:3];
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
    .mindex(2'b0),
    .jmp_pin(jmp_pin[0]),
    .gpio_pins(gpio_in),
    .input_pins(gpio_in),
    .output_pins(output_pins[0]),
    .pin_directions(pin_directions[0]),
    .sideset_bits(sideset_bits[0]),
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
    .mindex(2'b1),
    .jmp_pin(jmp_pin[1]),
    .gpio_pins(gpio_in),
    .input_pins(gpio_in),
    .output_pins(output_pins[1]),
    .pin_directions(pin_directions[1]),
    .sideset_bits(sideset_bits[1]),
    .div(div[1]),
    .instr(instr[pc2]),
    .pstart(pstart[1]),
    .pend(pend[1]),
    .pins_out_base(pins_out_base[1]),
    .pins_out_count(pins_out_count[1]),
    .pins_set_base(pins_set_base[1]),
    .pins_set_count(pins_set_count[1]),
    .pc(pc2),
    .din(din2),
    .dout(dout2)
  );

  machine machine_3 (
    .clk(clk),
    .reset(reset),
    .mindex(2'b10),
    .en(en[2]),
    .jmp_pin(jmp_pin[2]),
    .gpio_pins(gpio_in),
    .input_pins(gpio_in),
    .output_pins(output_pins[2]),
    .pin_directions(pin_directions[2]),
    .sideset_bits(sideset_bits[2]),
    .div(div[2]),
    .instr(instr[pc3]),
    .pstart(pstart[2]),
    .pend(pend[2]),
    .pins_out_base(pins_out_base[2]),
    .pins_out_count(pins_out_count[2]),
    .pins_set_base(pins_set_base[2]),
    .pins_set_count(pins_set_count[2]),
    .pc(pc3),
    .din(din3),
    .dout(dout3)
  );

  machine machine_4 (
    .clk(clk),
    .reset(reset),
    .en(en[3]),
    .mindex(2'b11),
    .jmp_pin(jmp_pin[3]),
    .gpio_pins(gpio_in),
    .input_pins(gpio_in),
    .output_pins(output_pins[3]),
    .pin_directions(pin_directions[3]),
    .sideset_bits(sideset_bits[3]),
    .div(div[3]),
    .instr(instr[pc4]),
    .pstart(pstart[3]),
    .pend(pend[3]),
    .pins_out_base(pins_out_base[3]),
    .pins_out_count(pins_out_count[3]),
    .pins_set_base(pins_set_base[3]),
    .pins_set_count(pins_set_count[3]),
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

