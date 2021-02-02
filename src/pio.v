`default_nettype none
module pio (
  input         clk,
  input         reset,
  input [1:0]   mindex,
  input [31:0]  din,
  input [4:0]   index,
  input [3:0]   action,
  output reg [31:0] dout,
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
  reg [3:0]   auto_pull;
  reg [3:0]   auto_push;
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
  reg [31:0]  initial_pins    [0:3];
  reg [31:0]  initial_dirs    [0:3];
  reg [4:0]   isr_threshold   [0:3];
  reg [4:0]   osr_threshold   [0:3];

  reg [3:0]   sideset_enable_bit = 4'b1111;
  reg [3:0]   shift_dir = 4'b1111;

  reg [3:0]   push;
  reg [3:0]   pull;

  wire [3:0]  empty;
  wire[3:0]   full;

  wire [3:0]  mpush;
  wire [3:0]  mpull;
  wire [31:0] output_pins [0:3];
  wire [31:0] pin_directions [0:3];
  wire [4:0]  pc [0:3];
  wire [31:0] mdin [0:3];
  wire [31:0] mdout [0:3];
  wire [31:0] pdout [0:3];

  assign gpio_out = output_pins[0]; // TODO: Combine outputs from machines
  assign gpio_dir = pin_directions[0];

  integer i;

  // Configure machines  
  always @(posedge clk) begin
    if (reset) begin
      en <= 0;
      jmp_pin <= 0;
      auto_pull <= 0;
      auto_push <= 0;
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
        initial_pins[i] <= 0;
        initial_dirs[i] <= 0;
        isr_threshold[i] <= 0;
        osr_threshold[i] <= 0;
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
       3: begin                             // Pull vsalue from fifo 
            pull[mindex] <= 1; 
            dout <= pdout[mindex]; 
          end
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
      11: jmp_pin <= din[3:0];              // Configure jump pins
      10: auto_push <= din[3:0];            // Configure auto_push
      11: auto_pull <= din[3:0];            // Configure auto_pull
      12: initial_pins[mindex] <= din;      // Configure initial output pin values
      13: initial_dirs[mindex] <= din;      // Configure initial pin directions
      14: isr_threshold[mindex] <= din[4:0]; // Configure auto_push threshold
      15: osr_threshold[mindex] <= din[4:0]; // Configure auto_pull threshold
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
        .sideset_enable_bit(sideset_enable_bit[j]),
        .shift_dir(shift_dir[j]),
        .div(div[j]),
        .instr(imm ? din[15:0] : instr[pc[j]]),
        .imm(imm),
        .pstart(pstart[j]),
        .pend(pend[0]),
        .pins_out_base(pins_out_base[j]),
        .pins_out_count(pins_out_count[j]),
        .pins_set_base(pins_set_base[j]),
        .pins_set_count(pins_set_count[j]),
        .pins_in_base(pins_in_base[j]),
        .pins_in_count(pins_in_count[j]),
        .pins_side_base(pins_side_base[j]),
        .pins_side_count(pins_side_count[j]),
        .auto_pull(auto_pull[j]),
        .auto_push(auto_push[j]),
        .initial_pins(initial_pins[j]),
        .initial_dirs(initial_dirs[j]),
        .isr_threshold(isr_threshold[j]),
        .osr_threshold(osr_threshold[j]),
        .pc(pc[j]),
        .din(mdin[j]),
        .dout(mdout[j]),
        .pull(mpull[j]),
        .push(mpush[j]),
        .empty(empty[j]),
        .full(full[j])
      );

      fifo fifo_tx (
        .clk(clk),
        .reset(reset),
        .push(push[j]),
        .pull(mpull[j]),
        .din(din),
        .dout(mdin[j]),
        .empty(empty[j])
      );

      fifo fifo_rx (
        .clk(clk),
        .reset(reset),
        .push(mpush[j]),
        .pull(pull[j]),
        .din(mdout[j]),
        .dout(pdout[j]),
        .full(full[j])
      );
    end
  endgenerate

endmodule

