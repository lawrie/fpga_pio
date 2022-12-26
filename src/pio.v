// SPDX-FileCopyrightText: 2022 Lawrie Griffiths
// SPDX-License-Identifier: BSD-2-Clause

`default_nettype none
module pio #(
  parameter NUM_MACHINES = 4
) (
  input             clk,
  input             reset,
  input [1:0]       mindex,
  input [31:0]      din,
  input [4:0]       index,
  input [3:0]       action,
  input [31:0]      gpio_in,
  output reg [31:0]     gpio_out,
  output reg [31:0]     gpio_dir,
  output reg [31:0] dout,
  output            irq0,
  output            irq1,
  output [3:0]      tx_full,
  output [3:0]      rx_empty,
  output [3:0]      pclk
);

  // Shared instructions memory
  reg [15:0]  instr [0:31];

  // Configuration
  reg [NUM_MACHINES-1:0]   en;
  reg [NUM_MACHINES-1:0]   auto_pull;
  reg [NUM_MACHINES-1:0]   auto_push;
  reg [NUM_MACHINES-1:0]   sideset_enable_bit;
  reg [NUM_MACHINES-1:0]   in_shift_dir;
  reg [NUM_MACHINES-1:0]   out_shift_dir;
  reg [NUM_MACHINES-1:0]   status_sel;
  reg [NUM_MACHINES-1:0]   out_sticky;
  reg [NUM_MACHINES-1:0]   inline_out_en;
  reg [NUM_MACHINES-1:0]   side_pindir;
  reg [NUM_MACHINES-1:0]   exec_stalled;
  reg [NUM_MACHINES-1:0]   use_divider;

  // Control
  reg [NUM_MACHINES-1:0]   imm;
  reg [NUM_MACHINES-1:0]   push;
  reg [NUM_MACHINES-1:0]   pull;
  reg [NUM_MACHINES-1:0]   restart;
  reg [NUM_MACHINES-1:0]   clkdiv_restart;

  // Configuration
  reg [4:0]   pend            [0:NUM_MACHINES-1];
  reg [4:0]   wrap_target     [0:NUM_MACHINES-1];
  reg [23:0]  div             [0:NUM_MACHINES-1];
  reg [4:0]   pins_in_base    [0:NUM_MACHINES-1];
  reg [4:0]   pins_out_base   [0:NUM_MACHINES-1];
  reg [4:0]   pins_set_base   [0:NUM_MACHINES-1];
  reg [4:0]   pins_side_base  [0:NUM_MACHINES-1];
  reg [5:0]   pins_out_count  [0:NUM_MACHINES-1];
  reg [2:0]   pins_set_count  [0:NUM_MACHINES-1];
  reg [2:0]   pins_side_count [0:NUM_MACHINES-1];
  reg [4:0]   isr_threshold   [0:NUM_MACHINES-1];
  reg [4:0]   osr_threshold   [0:NUM_MACHINES-1];
  reg [3:0]   status_n        [0:NUM_MACHINES-1];
  reg [4:0]   out_en_sel      [0:NUM_MACHINES-1];  
  reg [4:0]   jmp_pin         [0:NUM_MACHINES-1];

  (* mem2reg *) reg [15:0]  curr_instr      [0:NUM_MACHINES-1];

  // Output from machines and fifos
  wire [31:0] output_pins         [0:NUM_MACHINES-1];
  reg  [31:0] output_pins_prev    [0:NUM_MACHINES-1];
  wire [31:0] pin_directions      [0:NUM_MACHINES-1];
  reg  [31:0] pin_directions_prev [0:NUM_MACHINES-1];
  wire [4:0]  pc                  [0:NUM_MACHINES-1];
  wire [31:0] mdin                [0:NUM_MACHINES-1];
  wire [31:0] mdout               [0:NUM_MACHINES-1];
  wire [31:0] pdout               [0:NUM_MACHINES-1];
  wire [7:0]  irq_flags_out       [0:NUM_MACHINES-1];
  wire [2:0]  rx_level            [0:NUM_MACHINES-1];
  wire [2:0]  tx_level            [0:NUM_MACHINES-1];

  wire [NUM_MACHINES-1:0]  mempty;
  wire [NUM_MACHINES-1:0]  mfull;
  wire [NUM_MACHINES-1:0]  mpush;
  wire [NUM_MACHINES-1:0]  mpull;

  integer i;
  integer gpio_idx;

  // Synchronous fetch of current instruction for each machine
  always @(posedge clk) begin
    for(i=0;i<NUM_MACHINES;i=i+1) begin
      curr_instr[i] <= instr[pc[i]];

      // Coalesce output pins, making sure the highest PIO wins
      for(gpio_idx=0;gpio_idx<32;gpio_idx=gpio_idx+1) begin
        output_pins_prev[i][gpio_idx] <= output_pins[i][gpio_idx];
        if (output_pins[i][gpio_idx] != output_pins_prev[i][gpio_idx]) begin
          gpio_out[gpio_idx] <= output_pins[i][gpio_idx];
        end

        pin_directions_prev[i][gpio_idx] <= pin_directions[i][gpio_idx];
        if (pin_directions[i][gpio_idx] != pin_directions_prev[i][gpio_idx]) begin
          gpio_dir[gpio_idx] <= pin_directions[i][gpio_idx];
        end
      end
    end
  end

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

  // Configure and control machines
  always @(posedge clk) begin
    if (reset) begin
      en <= 0;
      auto_pull <= 0;
      auto_push <= 0;
      sideset_enable_bit <= 0;
      in_shift_dir <= 0;
      out_shift_dir <= 0;
      status_sel <= 0;
      out_sticky <= 0;
      inline_out_en <= 0;
      side_pindir <= 0;
      exec_stalled <= 0;
      for(i=0;i<NUM_MACHINES;i++) begin
        pend[i] <= 0;
        wrap_target[i] <= 0;
        div[i] <= 0; // no clock divider
        pins_in_base[i] <= 0;
        pins_out_base[i] <= 0;
        pins_set_base[i] <= 0;
        pins_side_base[i] <= 0;
        pins_out_count[i] <= 0;
        pins_set_count[i] <= 5;
        pins_side_count[i] <= 0;
        isr_threshold[i] <= 0;
        osr_threshold[i] <= 0;
        status_n[i] <= 0;
        out_en_sel[i] <= 0;
        jmp_pin[i] <= 0;
        output_pins_prev[i] <= 0;
        pin_directions_prev[i] <= 0;
      end
      gpio_out <= 0;
      gpio_dir <= 0;
    end else begin
      pull <= 0;
      push <= 0;
      imm <= 0;
      restart <= 0;
      clkdiv_restart <= 0;
      case (action)
        INSTR: instr[index] <= din[15:0];         // Set an instruction. INSTR_MEM registers
        PEND : begin                              // Configure pend, wrap_target, etc.
                 status_n[mindex] <= din[3:0];
                 status_sel[mindex] <= din[4];
                 wrap_target[mindex] <= din[11:7];
                 pend[mindex] <= din[16:12];
                 out_sticky[mindex] <= din[17];
                 inline_out_en[mindex] <= din[18];
                 out_en_sel[mindex] <= din[23:19];
                 jmp_pin[mindex] <= din[28:24];
                 side_pindir[mindex] <= din[29];
                 sideset_enable_bit[mindex] <= din[30];
                 exec_stalled[mindex] <= din[31];
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
        EN   : begin                              // Enable machines
                 en <= din[3:0];                  // Equivalent of CTRL register
                 restart <= din[7:4];
                 clkdiv_restart <= din[11:8];
               end
        DIV  : begin
                 div[mindex] <= din[23:0];        // Configure clock dividers. CLKDIV registers
                 use_divider[mindex] <= din[23:0] >= 24'h200;  // Use divider if clock divider is 2 or more
               end
        IMM  : imm[mindex] <= 1;                  // Immediate instruction
        SHIFT: begin
                 auto_push[mindex] <= din[16];    // SHIFT_CTRL
                 auto_pull[mindex] <= din[17];
                 in_shift_dir[mindex] <= din[18];
                 out_shift_dir[mindex] <= din[19];
                 isr_threshold[mindex] <= din[24:20];
                 osr_threshold[mindex] <= din[29:25];
               end
        NONE  : dout <= 32'h01000000; // Hardware version number
      endcase
    end
  end

  // Generate the machines and associated TX and RX fifos
  generate
    genvar j;

    for(j=0;j<NUM_MACHINES;j=j+1) begin : mach
      machine machine (
        .clk(clk),
        .reset(reset),
        .en(en[j]),
        .restart(restart[j]),
        .mindex(j[1:0]),
        .jmp_pin(jmp_pin[j]),
        .input_pins(gpio_in),
        .output_pins(output_pins[j]),
        .pin_directions(pin_directions[j]),
        .sideset_enable_bit(pins_side_count[j] > 0 ? sideset_enable_bit[j] : 1'b0),
        .in_shift_dir(in_shift_dir[j]),
        .out_shift_dir(out_shift_dir[j]),
        .div(div[j]),
        .use_divider(use_divider[j]),
        .instr(imm[j] ? din[15:0] : curr_instr[j]),
        .imm(imm[j]),
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
        .isr_threshold(isr_threshold[j]),
        .osr_threshold(osr_threshold[j]),
        .irq_flags_in(8'h0),
        .irq_flags_out(irq_flags_out[j]),
        .pc(pc[j]),
        .din(mdin[j]),
        .dout(mdout[j]),
        .pull(mpull[j]),
        .push(mpush[j]),
        .pclk(pclk[j]),
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
        .full(tx_full[j]),
        .level(tx_level[j])
      );

      fifo fifo_rx (
        .clk(clk),
        .reset(reset),
        .push(mpush[j]),
        .pull(pull[j]),
        .din(mdout[j]),
        .dout(pdout[j]),
        .full(mfull[j]),
        .empty(rx_empty[j]),
        .level(rx_level[j])
      );
    end
  endgenerate

endmodule
