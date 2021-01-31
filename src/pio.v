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
  reg [3:0]   en;
  reg [3:0]   jmp_pin;
  reg         imm;
  
  reg [4:0]   pstart          [0:3];
  reg [4:0]   pend            [0:3];
  reg [23:0]  div             [0:3];
  reg [4:0]   pins_in_base    [0:3];
  reg [2:0]   pins_in_count   [0:3];
  reg [4:0]   pins_out_base   [0:3];
  reg [2:0]   pins_out_count  [0:3];
  reg [4:0]   pins_set_base   [0:3];
  reg [2:0]   pins_set_count  [0:3];
  reg [4:0]   pins_side_base  [0:3];
  reg [2:0]   pins_side_count [0:3];
  reg [2:0]   sideset_bits    [0:3];

  reg [3:0]   push;
  reg [3:0]   pull;
  
  wire [3:0]   empty;
  wire[3:0]    full;

  wire [3:0]  mpush;
  wire [3:0]  mpull;
  wire [31:0] output_pins [0:3];
  wire [31:0] pin_directions [0:3];
  wire [4:0]  pc [0:3];
  wire [31:0] mdin [0:3];
  wire [31:0] mdout [0:3];

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
        pins_in_count[i] <= 0;
        pins_in_base[i] <= 0;
        pins_out_count[i] <= 0;
        pins_out_base[i] <= 0;
        pins_set_count[i] <= 0;
        pins_set_base[i] <= 0;
        pins_side_count[i] <= 0;
        pins_side_base[i] <= 0;
        sideset_bits[i] <= 0;
      end
    end else begin
     wrap <= 0;
     pull <= 0;
     push <= 0;
     imm <= 0;
     case (action)
       1: instr[index] <= din[15:0];        // Set an instruction
       2: begin                             // Configure pend
            pend[mindex] <= index; 
          end 
       3: pull[mindex] <= 1;                // Pull a value from fifo
       4: push[mindex] <= 1;                // Push a value to fifo
       5: begin                             // Configure pin groups
            pins_set_count[mindex]  <= din[2:0];
            pins_set_base[mindex]   <= din[7:3];
            pins_out_count[mindex]  <= din[10:8];
            pins_out_base[mindex]   <= din[15:11];
            pins_in_count[mindex]   <= din[18:16];
            pins_in_base[mindex]    <= din[23:19];
            pins_side_count[mindex] <= din[26:24];
            pins_side_base[mindex]  <= din[31:27];
          end
       6: en <= din[3:0];                   // Enable machines
       7: div[mindex] <= din[23:0];         // Configure clock dividers
       8: sideset_bits[mindex] <= din[4:0]; // Configure side-set bits
       9: imm <= 1;                         // Immediate instruction
      10: jmp_pin <= din[3:0];              // Configure jump pins
     endcase
    end
  end

  generate
    genvar j;

    for(j=0;j<4;j=j+1) begin : mach
      machine machine (
        .clk(clk),
        .reset(reset),
        .en(en[j]),
        .mindex(j[1:0]),
        .jmp_pin(jmp_pin[j]),
        .gpio_pins(gpio_in),
        .input_pins(gpio_in),
        .output_pins(output_pins[j]),
        .pin_directions(pin_directions[j]),
        .sideset_bits(sideset_bits[j]),
        .div(div[j]),
        .instr(imm ? din[15:0] : instr[pc[j]]),
        .imm(imm),
        .pstart(pstart[j]),
        .pend(pend[0]),
        .pins_out_base(pins_out_base[j]),
        .pins_out_count(pins_out_count[j]),
        .pins_set_base(pins_set_base[j]),
        .pins_set_count(pins_set_count[j]),
        .pc(pc[j]),
        .din(mdin[j]),
        .dout(mdout[j]),
        .pull(mpull[j]),
        .push(mpush[j]),
        .empty(empty[j]),
        .full(full[j])
      );
    end
  endgenerate

  fifo fifo_tx_1 (
    .clk(clk),
    .reset(reset),
    .push(push[0]),
    .pull(pull[0]),
    .din(din),
    .dout(mdin[0]),
    .empty(empty[0])
  );

  fifo fifo_rx_1 (
    .clk(clk),
    .reset(reset),
    .push(push[0]),
    .pull(pull[0]),
    .din(din),
    .dout(dout),
    .full(full[0])
  );

  fifo fifo_tx_2 (
    .clk(clk),
    .reset(reset),
    .push(push[1]),
    .pull(pull[1]),
    .din(din),
    .dout(mdin[1]),
    .empty(empty[1])
  );

  fifo fifo_rx_2 (
    .clk(clk),
    .reset(reset),
    .push(push[1]),
    .pull(pull[1]),
    .din(din),
    .dout(dout),
    .full(full[1])
  );

  fifo fifo_tx_3 (
    .clk(clk),
    .reset(reset),
    .push(push[2]),
    .pull(pull[2]),
    .din(din),
    .dout(mdin[2]),
    .empty(empty[2])
  );

  fifo fifo_rx_3 (
    .clk(clk),
    .reset(reset),
    .push(push[2]),
    .pull(pull[2]),
    .din(din),
    .dout(dout),
    .full(full[2])
  );

  fifo fifo_tx_4 (
    .clk(clk),
    .reset(reset),
    .push(push[3]),
    .pull(pull[3]),
    .din(din),
    .dout(mdin[3]),
    .empty(empty[0])
  );

  fifo fifo_rx_4 (
    .clk(clk),
    .reset(reset),
    .push(push[3]),
    .pull(pull[3]),
    .din(din),
    .dout(dout),
    .full(full[3])
  );

endmodule

