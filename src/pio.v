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
  output        irq1,
  output [3:0]  full,
  output [3:0]  empty
);

  // Shared instructions memory
  reg [15:0]  instr [0:31];

  reg         wrap;
  reg [3:0]   en;
  reg [3:0]   restart;
  reg [3:0]   clkdiv_restart;
  reg [3:0]   jmp_pin;
  reg [3:0]   auto_pull;
  reg [3:0]   auto_push;
  reg         imm;
  
  reg [4:0]   pstart          [0:3];
  reg [4:0]   pend            [0:3];
  reg [4:0]   wrap_target     [0:3];
  reg [23:0]  div             [0:3];
  reg [4:0]   pins_in_base    [0:3];
  reg [4:0]   pins_out_base   [0:3];
  reg [5:0]   pins_out_count  [0:3];
  reg [4:0]   pins_set_base   [0:3];
  reg [2:0]   pins_set_count  [0:3];
  reg [4:0]   pins_side_base  [0:3];
  reg [2:0]   pins_side_count [0:3];
  reg [2:0]   sideset_bits    [0:3];
  reg [31:0]  initial_pins    [0:3];
  reg [31:0]  initial_dirs    [0:3];
  reg [4:0]   isr_threshold   [0:3];
  reg [4:0]   osr_threshold   [0:3];

  reg [3:0]   sideset_enable_bit;
  reg [3:0]   sideset_enabled;
  reg [3:0]   in_shift_dir;
  reg [3:0]   out_shift_dir;

  reg [3:0]   push;
  reg [3:0]   pull;

  wire [3:0]  mempty;
  wire[3:0]   mfull;

  wire [3:0]  mpush;
  wire [3:0]  mpull;

  wire [31:0] output_pins    [0:3];
  wire [31:0] pin_directions [0:3];
  wire [4:0]  pc             [0:3];
  wire [31:0] mdin           [0:3];
  wire [31:0] mdout          [0:3];
  wire [31:0] pdout          [0:3];
  wire [7:0]  irq_flags_out  [0:3];

  assign gpio_out = output_pins[0]; // TODO: Combine outputs from machines
  assign gpio_dir = pin_directions[0];

  integer i;

  // Actions
  localparam NONE  = 0;
  localparam INSTR = 1;
  localparam PEND  = 2;
  localparam PULL  = 3;
  localparam PUSH  = 4;
  localparam GRPS  = 5;
  localparam EN    = 6;
  localparam DIV   = 7;
  localparam SIDES = 8;
  localparam IMM   = 9;
  localparam SHIFT = 10;
  localparam IPINS = 11;
  localparam IDIRS = 12;

  // Configure machines
  always @(posedge clk) begin
    if (reset) begin
      en <= 0;
      restart <= 0;
      jmp_pin <= 0;
      auto_pull <= 0;
      auto_push <= 0;
      out_shift_dir <= 0;
      in_shift_dir <= 0;
      sideset_enabled <= 4'b1111;
      for(i=0;i<4;i++) begin
        div[i] <= 0; // no clock divider
        pend[i] <= 0;
        pstart[i] <= 0;
        wrap_target[i] <= 0;
        pins_in_base[i] <= 0;
        pins_out_count[i] <= 0;
        pins_out_base[i] <= 0;
        pins_set_count[i] <= 5;
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
       INSTR: instr[index] <= din[15:0];         // Set an instruction. INSTR_MEM registers
       PEND : begin                              // Configure pstart, pend, wrap_target
                pend[mindex] <= din[4:0];
                pstart[mindex] <= din [9:5];
                wrap_target[mindex] <= din[14:10];
              end
       PULL : begin                              // Pull value from fifo 
                pull[mindex] <= 1; 
                dout <= pdout[mindex]; 
              end
       PUSH : push[mindex] <= 1;                 // Push a value to fifo
       GRPS : begin                              // Configure pin groups. PIN_CTRL registers
                pins_out_base[mindex]   <= din[4:0];
                pins_set_base[mindex]   <= din[9:5];
                pins_side_base[mindex]  <= din[14:10];
                pins_in_base[mindex]    <= din[19:15];
                pins_out_count[mindex]  <= din[25:20];
                pins_set_count[mindex]  <= din[28:26];
                pins_side_count[mindex] <= din[31:29];
              end
       EN   : begin                             // Enable machines
                en <= din[3:0];                 // Equivalent of CTRL register
                restart <= din[7:4];
                clkdiv_restart <= din[11:8];
              end
       DIV  : div[mindex] <= din[23:0];          // Configure clock dividers. CLKDIV registers
       SIDES: begin                              // Configure side-set bits
                sideset_bits[mindex] <= din[4:0];
                sideset_enabled[mindex] <= ~din[5];
              end
       IMM  : imm <= 1;                           // Immediate instruction
       //JMP  : jmp_pin <= din[3:0];              // Configure jump pins
       SHIFT: begin
                auto_push[mindex] <= din[16];     // SHIFT_CTRL
                auto_pull[mindex] <= din[17];
                in_shift_dir[mindex] <= din[18];
                out_shift_dir[mindex] <= din[19];
                isr_threshold[mindex] <= din[24:20];
                osr_threshold[mindex] <= din[29:25];
              end
       IPINS: initial_pins[mindex] <= din;        // Configure initial output pin values
       IDIRS: initial_dirs[mindex] <= din;        // Configure initial pin directions
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
        .restart(restart[j]),
        .mindex(j[1:0]),
        .jmp_pin(jmp_pin[j]),
        .gpio_pins(gpio_in),
        .input_pins(gpio_in),
        .output_pins(output_pins[j]),
        .pin_directions(pin_directions[j]),
        .sideset_bits(sideset_bits[j]),
        .sideset_enable_bit(sideset_bits[j] > 0 ? sideset_enabled[j] : 1'b0),
        .in_shift_dir(in_shift_dir[j]),
        .out_shift_dir(out_shift_dir[j]),
        .div(div[j]),
        .instr(imm ? din[15:0] : instr[pstart[j] + pc[j]]),
        .imm(imm),
        .pend(pend[j]),
        .wrap_target(wrap_target[j]),
        .pins_out_base(pins_out_base[j]),
        .pins_out_count(pins_out_count[j]),
        .pins_set_base(pins_set_base[j]),
        .pins_set_count(pins_set_count[j]),
        .pins_in_base(pins_in_base[j]),
        .pins_side_base(pins_side_base[j]),
        .pins_side_count(pins_side_count[j]),
        .auto_pull(auto_pull[j]),
        .auto_push(auto_push[j]),
        .initial_pins(initial_pins[j]),
        .initial_dirs(initial_dirs[j]),
        .isr_threshold(isr_threshold[j]),
        .osr_threshold(osr_threshold[j]),
        .irq_flags_in(8'h0),
        .irq_flags_out(irq_flags_out[j]),
        .pc(pc[j]),
        .din(mdin[j]),
        .dout(mdout[j]),
        .pull(mpull[j]),
        .push(mpush[j]),
        .empty(mempty[j]),
        .full(mfull[j])
      );

      fifo fifo_tx (
        .clk(clk),
        .reset(reset),
        .push(push[j]),
        .pull(mpull[j]),
        .din(din),
        .dout(mdin[j]),
        .empty(mempty[j]),
        .full(full[j])
      );

      fifo fifo_rx (
        .clk(clk),
        .reset(reset),
        .push(mpush[j]),
        .pull(pull[j]),
        .din(mdout[j]),
        .dout(pdout[j]),
        .full(mfull[j]),
        .empty(empty[j])
      );
    end
  endgenerate

endmodule

