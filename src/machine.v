// SPDX-FileCopyrightText: 2022 Lawrie Griffiths
// SPDX-License-Identifier: BSD-2-Clause

`default_nettype none
module machine (
  input         clk,
  input         reset,
  input         en,
  input [23:0]  div,
  input         use_divider,
  input [31:0]  din,
  input [15:0]  instr,
  input [31:0]  input_pins,
  input [7:0]   irq_flags_in,
  input         imm,
  input         empty,
  input         full,
  input         restart,

  // Configuration
  input [1:0]   mindex,
  input [4:0]   pend,
  input [4:0]   wrap_target,
  input [4:0]   jmp_pin,
  input         sideset_enable_bit,
  input [4:0]   pins_out_base,
  input [5:0]   pins_out_count,
  input [4:0]   pins_set_base,
  input [2:0]   pins_set_count,
  input [4:0]   pins_in_base,
  input [4:0]   pins_side_base,
  input [2:0]   pins_side_count,
  input         out_shift_dir,
  input         in_shift_dir,
  input         auto_pull,
  input         auto_push,
  input [4:0]   isr_threshold,
  input [4:0]   osr_threshold,

  // Output
  output [4:0]  pc,
  output reg    push, // Send data to RX FIFO
  output reg    pull, // Get data from TX FIFO
  output reg [31:0] dout,
  output reg [31:0] output_pins,
  output reg [31:0] pin_directions,
  output reg [7:0]  irq_flags_out,
  output        pclk
);

  // Strobes to implement instructions (combinatorial)
  reg         jmp;
  reg         setx;
  reg         sety;
  reg         decx;
  reg         decy;
  reg         set_shift_in;
  reg         set_shift_out;
  reg         do_in_shift;
  reg         do_out_shift;
  reg         set_set_pins;
  reg         set_set_dirs;
  reg         set_out_pins;
  reg         set_out_dirs;
  reg         set_side_pins;
  reg         set_side_dirs;
  reg         exec;
  reg         waiting;
  reg         auto;

  reg [5:0]   bit_count;
  reg [31:0]  new_val;
  
  reg         exec1 = 0;
  reg [15:0]  exec_instr;
 
  // Divided clock enable signal 
  wire        penable;

  // Output from modules
  wire [31:0] x;
  wire [31:0] y;
  wire [31:0] in_shift;
  wire [31:0] out_shift;
  wire [2:0]  op;
  wire [2:0]  op1;
  wire [4:0]  op2;
  wire [4:0]  delay;
  wire [4:0]  side_set;
  wire        sideset_enabled;
  
  // Names of operands
  wire        blocking = op1[0];
  wire        if_full = op1[1];
  wire        if_empty = op1[1];
  wire [2:0]  destination = op1;
  wire [2:0]  source = op1;
  wire [2:0]  condition = op1;
  wire [1:0]  source2 = op1[1:0];
  wire        polarity = op1[2];
  wire [4:0]  index = op2;
  wire [4:0]  address = op2;
  wire [4:0]  data = op2;
  wire [1:0]  irq_rel = op2[4] ? mindex + op2[1:0] : op2[1:0];
  wire [2:0]  irq_index = {op2[2], irq_rel};
  wire [2:0]  mov_source = op2[2:0];
  wire [1:0]  mov_op = op2[4:3];

  // Miscellaneous signals
  wire [31:0] null = 0; // NULL source
  wire [5:0]  isr_count, osr_count;
  wire [31:0] in_pins = input_pins << pins_in_base;

  // Values for use in gtkwave during simulation
  wire        pin0 = output_pins[0];
  wire        pin1 = output_pins[1];
  wire        pin2 = output_pins[2];
  wire        pin3 = output_pins[3];

  wire        in_pin0 = input_pins[0];

  reg [4:0]   delay_cnt = 0;

  // States
  wire enabled  = exec1 || imm || (en && penable); // Instruction execution enabled
  wire delaying = delay_cnt > 0;

  // Function to reverse the order of bits in a word
  function [31:0] reverse (
    input [31:0] in
  );

    integer i;
    for(i=0;i<32;i=i+1) begin
      reverse[i] = in[31-i];
    end
  endfunction

  // Function to apply selected bit operation to a word
  function [31:0] bit_op (
    input [31:0] in,
    input [1:0] op
  );

    case (op) 
      0: bit_op = in;
      1: bit_op = ~in;
      2: bit_op = reverse(in);
      3: bit_op = in; // Reserved
    endcase
  endfunction

  // Tasks to set registers
  task set_x (
    input [31:0] val
  );
    begin 
      setx = 1;
      new_val = val;
    end
  endtask

  task set_y (
    input [31:0] val
  );
    begin
      sety = 1;
      new_val = val;
    end
  endtask

  task set_exec (
    input [31:0] val
  );
    begin
      exec = 1;
      new_val = val;
    end
  endtask

  task set_pc (
    input [31:0] val
  );
    begin
      jmp = 1;
      new_val = val;
    end
  endtask

  task set_isr (
    input [31:0] val
  );
    begin
      set_shift_in = 1;
      new_val = val;
    end
  endtask

  task set_osr (
    input [31:0] val
  );
    begin
      set_shift_out = 1;
      new_val = val;
    end
  endtask

  task do_shift_in (
    input [31:0] val
  );
    begin
      do_in_shift = 1;
      new_val = val;
    end
  endtask

  task pins_set (
    input [31:0] val
  );
    begin
      set_set_pins = 1;
      new_val = val;
    end
  endtask

  task dirs_set (
    input [31:0] val
  );
    begin
      set_set_dirs = 1;
      new_val = val;
    end
  endtask

  task pins_out (
    input [31:0] val
  );
    begin
      set_out_pins = 1;
      new_val = val;
    end
  endtask

  task dirs_out (
    input [31:0] val
  );
    begin
      set_out_dirs = 1;
      new_val = val;
    end
  endtask

  task do_push();
    begin
      push = 1;
      dout = in_shift;
    end
  endtask

  task do_pull ();
    begin
      pull = 1;
      set_shift_out = 1;
      new_val = din;
    end
  endtask

  // Instructions
  localparam JMP  = 0;
  localparam WAIT = 1;
  localparam IN   = 2;
  localparam OUT  = 3;
  localparam PUSH = 4;
  localparam PULL = 4;
  localparam MOV  = 5;
  localparam IRQ  = 6;
  localparam SET  = 7;

  // Count down if delay
  always @(posedge clk) begin
    if (reset || restart) begin
      delay_cnt <= 0;
      pin_directions <= 32'h00000000;
      output_pins <= 32'h00000000;
    end else if (en & penable) begin
      exec1 <= exec; // Do execition on next cycle after exec set
      exec_instr <= new_val;
      if (delaying) delay_cnt <= delay_cnt - 1;
      else if (!waiting && !exec && delay > 0) delay_cnt <= delay;
    end
  end
 
  integer i;

  always @(posedge clk) begin
    if (enabled && !delaying) begin
      if (sideset_enabled && !(auto && !waiting)) // TODO Is auto test correct?
        for (i=0;i<5;i++) 
          if (pins_side_count > i) output_pins[pins_side_base+i] <= side_set[i];
      if (set_set_pins)
        for (i=0;i<5;i++) 
          if (pins_set_count > i) output_pins[pins_set_base+i] <= new_val[i];
      if (set_set_dirs)
        for (i=0;i<5;i++) 
          if (pins_set_count > i) pin_directions[pins_set_base+i] <= new_val[i];
      if (set_out_pins)
        for (i=0;i<5;i++) 
          if (pins_out_count > i) output_pins[pins_out_base+i] <= new_val[i];
      if (set_out_dirs)
        for (i=0;i<5;i++) 
          if (pins_out_count > i) pin_directions[pins_out_base+i] <= new_val[i];
    end
  end
  
  // Execute the current instruction
  always @* begin
    jmp  = 0;
    pull = 0;
    push = 0;
    set_shift_in = 0;
    set_shift_out = 0;
    do_in_shift = 0;
    do_out_shift = 0;
    decx = 0;
    decy = 0;
    setx = 0;
    sety = 0;
    exec = 0;
    waiting = 0;
    auto = 0;
    new_val = 0;
    bit_count = 0;
    set_set_pins = 0;
    set_set_dirs = 0;
    set_out_pins = 0;
    set_out_dirs = 0;
    irq_flags_out = 0;
    dout = 0;
    if (enabled && !delaying) begin
      case (op)
        JMP:  begin
                new_val[4:0] = address; 
                case (condition) // Condition
                  0: jmp = 1;
                  1: jmp = (x == 0);
                  2: begin jmp = (x != 0); decx = (x != 0); end
                  3: jmp = (y == 0);
                  4: begin jmp = (y != 0); decy = (y != 0); end
                  5: jmp = (x != y);
                  6: jmp = jmp_pin;
                  7: jmp = (osr_count < osr_threshold);
                endcase
              end
        WAIT: case (source2) // Source
                0: waiting = input_pins[index] != polarity;
                1: waiting = input_pins[pins_in_base + index] != polarity;
                2: waiting = irq_flags_out[irq_index] != polarity;
              endcase
        IN:   if (auto_push && isr_count >= isr_threshold) begin // Auto push
                 do_push();
                 set_isr(0); 
                 waiting = full; 
                 auto = 1;
              end else case (source) // Source
                0: do_shift_in(in_pins);
                1: do_shift_in(x);
                2: do_shift_in(y);
                3: do_shift_in(null);
                6: do_shift_in(in_shift);
                7: do_shift_in(out_shift);
              endcase
        OUT:  if (auto_pull && osr_count >= osr_threshold) begin // Auto push
                 do_pull();
                 waiting = empty;
                 auto = 1;
              end else case (destination) // Destination
                0: begin do_out_shift = 1; pins_out(out_shift); end                                    // PINS
                1: begin do_out_shift = 1; set_x(out_shift); end                                       // X
                2: begin do_out_shift = 1; set_y(out_shift); end                                       // Y
                4: begin do_out_shift = 1; dirs_out(out_shift); end                                    // PINDIRS
                5: begin do_out_shift = 1; set_pc(out_shift);          ; end                           // PC
                6: begin do_out_shift = 1; set_isr(out_shift); bit_count = op2; end                    // ISR
                7: begin do_out_shift = 1; set_exec(out_shift[15:0]); end                              // EXEC
              endcase
        PUSH: if (!op1[2]) begin // PUSH TODO No-op when auto-push?
                if (!if_full || (isr_count >= isr_threshold)) begin
                  do_push();
                  set_isr(0);
                  waiting = blocking && full;
                end
              end else begin // PULL TODO No-op when auto-pull?
                if (!if_empty || (osr_count >= osr_threshold)) begin
                  if (blocking) begin // Blocking
                    do_pull();
                    waiting = empty;
                  end else begin
                    if (empty) begin // Copy X to OSR
                      set_osr(x);
                    end else begin // Pull value if available
                      do_pull();
                    end
                  end
                end
              end
        MOV:  case (destination)  // Destination TODO Status source
                0: case (mov_source) // PINS
                     1: pins_out(bit_op(x, mov_op));         // X
                     2: pins_out(bit_op(y, mov_op));         // Y
                     3: pins_out(bit_op(null, mov_op));      // NULL
                     6: pins_out(bit_op(in_shift, mov_op));  // ISR
                     7: pins_out(bit_op(out_shift, mov_op)); // OSR
                   endcase
                1: case (mov_source) // X
                     0: set_x(bit_op(in_pins, mov_op));      // PINS
                     2: set_x(bit_op(y, mov_op));            // Y
                     3: set_x(bit_op(null, mov_op));         // NULL
                     6: set_x(bit_op(in_shift, mov_op));     // ISR
                     7: set_x(bit_op(out_shift, mov_op));    // OSR
                   endcase
                2: case (mov_source) // Y
                     0: set_y(bit_op(in_pins, mov_op));      // PINS
                     1: set_y(bit_op(x, mov_op));            // X
                     3: set_y(bit_op(null, mov_op));         // NULL
                     6: set_y(bit_op(in_shift, mov_op));     // ISR
                     7: set_y(bit_op(out_shift, mov_op));    // OSR
                   endcase
                4: case (mov_source) // EXEC
                     0: set_exec(bit_op(in_pins, mov_op));   // PINS
                     1: set_exec(bit_op(x, mov_op));         // X
                     2: set_exec(bit_op(y, mov_op));         // Y
                     3: set_exec(bit_op(null, mov_op));      // NULL
                     6: set_exec(bit_op(in_shift, mov_op));  // ISR
                     7: set_exec(bit_op(out_shift, mov_op)); // OSR
                   endcase
                5: case (mov_source) // PC
                     0: set_pc(bit_op(in_pins, mov_op));     // PINS
                     1: set_pc(bit_op(x, mov_op));           // X
                     2: set_pc(bit_op(y, mov_op));           // Y
                     3: set_pc(bit_op(null, mov_op));        // NULL
                     6: set_pc(bit_op(in_shift, mov_op));    // ISR
                     7: set_pc(bit_op(out_shift, mov_op));   // OSR
                   endcase
                6: case (mov_source) // ISR
                     0: set_isr(bit_op(in_pins, mov_op));    // PINS
                     1: set_isr(bit_op(x, mov_op));          // X
                     2: set_isr(bit_op(y, mov_op));          // Y
                     3: set_isr(bit_op(null, mov_op));       // NULL
                     6: set_isr(bit_op(in_shift, mov_op));   // ISR
                     7: set_isr(bit_op(out_shift, mov_op));  // OSR
                   endcase
                7: case (mov_source) // OSR
                     0: set_osr(bit_op(in_pins, mov_op));    // PINS
                     1: set_osr(bit_op(x, mov_op));          // X
                     2: set_osr(bit_op(y, mov_op));          // Y
                     3: set_osr(bit_op(null, mov_op));       // NULL
                     6: set_osr(bit_op(in_shift, mov_op));   // ISR
                     7: set_osr(bit_op(out_shift, mov_op));  // OSR
                   endcase
              endcase
        IRQ:  begin
                if (op1[1]) irq_flags_out[irq_index] = 0;    // CLEAR
                else begin                                   // SET
                  irq_flags_out[irq_index] = 1;
                  waiting = blocking && irq_flags_in[irq_index] != 0; // If wait set, wait for irq cleared
                end
              end
        SET:  case (destination) // Destination
                0: pins_set(data);                           // PINS
                1: set_x({27'b0, data});                     // X
                2: set_y({27'b0, data});                     // Y
                4: dirs_set(data);                           // PINDIRS
              endcase
      endcase
    end
  end

  // Clock divider
  divider clk_divider (
    .clk(clk),
    .reset(reset | restart),
    .div(div),
    .use_divider(use_divider),
    .penable(penable),
    .pclk(pclk)
  );

  // Instruction decoder
  decoder decode (
    .instr(exec1 ? exec_instr : instr),
    .sideset_bits(pins_side_count),
    .sideset_enable_bit(sideset_enable_bit),
    .sideset_enabled(sideset_enabled),
    .op(op),
    .op1(op1),
    .op2(op2),
    .delay(delay),
    .side_set(side_set)
  );

  // Synchronous modules
  // PC
  pc pc_reg (
    .clk(clk),
    .penable(en & penable),
    .reset(reset | restart),
    .din(new_val[4:0]),
    .jmp(jmp),
    .stalled(waiting || auto || imm || exec1 || delaying),
    .pend(pend),
    .wrap_target(wrap_target),
    .dout(pc)
  );

  // X
  scratch scratch_x (
    .clk(clk),
    .penable(enabled),
    .reset(reset | restart),
    .stalled(delaying),
    .din(new_val),
    .set(setx),
    .dec(decx),
    .dout(x)
  );

  // Y
  scratch scratch_y (
    .clk(clk),
    .penable(enabled),
    .reset(reset | restart),
    .stalled(delaying),
    .din(new_val),
    .set(sety),
    .dec(decy),
    .dout(y)
  );

  // ISR
  isr shift_in (
    .clk(clk),
    .penable(enabled),
    .reset(reset | restart),
    .stalled(waiting ||delaying),
    .dir(in_shift_dir),
    .shift(op2),
    .set(set_shift_in),
    .do_shift(do_in_shift),
    .din(new_val),
    .dout(in_shift),
    .bit_count(bit_count),
    .shift_count(isr_count)
  );

  // OSR
  osr shift_out (
    .clk(clk),
    .penable(enabled),
    .reset(reset | restart),
    .stalled(waiting || delaying),
    .dir(out_shift_dir),
    .shift(op2),
    .set(set_shift_out),
    .do_shift(do_out_shift),
    .din(new_val),
    .dout(out_shift),
    .shift_count(osr_count)
  );

endmodule
