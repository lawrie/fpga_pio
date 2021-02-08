`default_nettype none
module machine (
  input         clk,
  input         reset,
  input         en,
  input [23:0]  div,
  input [31:0]  din,
  input [15:0]  instr,
  input [31:0]  input_pins,
  input [31:0]  gpio_pins,
  input [7:0]   irq_flags_in,
  input         imm,
  input         empty,
  input         full,
  input         restart,

  // Configuration
  input [1:0]   mindex,
  input [4:0]   pend,
  input [4:0]   wrap_target,
  input         jmp_pin,
  input [2:0]   sideset_bits,
  input         sideset_enable_bit,
  input [4:0]   pins_out_base,
  input [2:0]   pins_out_count,
  input [4:0]   pins_set_base,
  input [2:0]   pins_set_count,
  input [4:0]   pins_in_base,
  input [2:0]   pins_in_count,
  input [4:0]   pins_side_base,
  input [2:0]   pins_side_count,
  input         shift_dir,
  input         auto_pull,
  input         auto_push,
  input [4:0]   isr_threshold,
  input [4:0]   osr_threshold,
  input [31:0]  initial_pins,
  input [31:0]  initial_dirs,

  // Output
  output [4:0]  pc,
  output reg    push, // Send data to output FIFO
  output reg    pull, // Get data from input FIFO
  output reg [31:0] dout,
  output reg [31:0] output_pins,
  output reg [31:0] pin_directions,
  output reg [7:0]  irq_flags_out
);

  // Strobes to implement instructions (cominatorial)
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
  reg         set_in_pins;
  reg         set_in_dirs;
  reg         exec;
  reg         exec1 = 0;
  reg         waiting;
  reg         auto;

  reg [31:0]  new_val;
  reg [15:0]  exec_instr;
  reg [15:0]  exec1_instr;
 
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

  // Miscellaneous signals
  wire [1:0]  irq_rel = op2[4] ? mindex + op2[1:0] : op2[1:0];
  wire [2:0]  irq_index = {op2[2], irq_rel};
  wire [31:0] null = 0; // NULL source
  wire [5:0]  isr_count, osr_count;

  // Values for use in gtkwave during simulation
  wire        pin0 = output_pins[0];
  wire        pin1 = output_pins[1];
  wire        pin2 = output_pins[2];
  wire        in_pin0 = input_pins[0];

  reg [4:0]   delay_cnt = 0;
  reg [5:0]   bit_count;

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
      3: bit_op = in;
    endcase
  endfunction

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
    if (reset || restart) 
      delay_cnt <= 0;
    else if (en & penable) begin
      exec1 <= exec;
      exec1_instr <= exec_instr;
      if (delaying) delay_cnt <= delay_cnt - 1;
      else if (!waiting && !exec && delay > 0) delay_cnt <= delay;
    end
  end
 
  integer i;

  // Set output pins and pin directions 
  always @(posedge clk) begin
    if (enabled && !delaying) begin // TODO Set mask to allow multiplex of results from multiple machines
      if (sideset_enabled && !(auto && !waiting))
        for (i=0;i<5;i++) 
          if (pins_side_count > i) output_pins[pins_side_base+i] <= side_set[i];
      if (set_set_pins)
        for (i=0;i<5;i++) 
          if (pins_set_count > i) output_pins[pins_set_base+i] <= op2[i];
      if (set_set_dirs)
        for (i=0;i<5;i++) 
          if (pins_set_count > i) pin_directions[pins_set_base+i] <= op2[i];
      if (set_out_pins)
        for (i=0;i<5;i++) 
          if (pins_out_count > i) output_pins[pins_out_base+i] <= new_val[i];
      if (set_out_dirs)
        for (i=0;i<5;i++) 
          if (pins_out_count > i) pin_directions[pins_out_base+i] <= op2[i];
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
      set_in_pins = 0;
      set_in_dirs = 0;
      exec_instr = 0;
      irq_flags_out = 0;
      dout = 0;
      if (enabled && !delaying) begin
        case (op)
          JMP:  begin
                  new_val[4:0] = op2; 
                  case (op1) // Condition
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
	  WAIT: case (op1[1:0]) // Source
                  0: waiting = gpio_pins[op2] != op1[2];
                  1: waiting = input_pins[op2] != op1[2];
                  2: waiting = irq_flags_out[irq_index] != op1[2];
                endcase
          IN:   if (auto_push && isr_count >= isr_threshold) begin
                   push = 1; 
                   dout = in_shift; 
                   new_val = 0; 
                   bit_count = 0; 
                   set_shift_in = !full; 
                   waiting = full; 
                   auto = 1;
                end else case (op1) // Source
                  0: begin do_in_shift = 1; new_val = input_pins; end
                  1: begin do_in_shift = 1; new_val = x; end
                  2: begin do_in_shift = 1; new_val = y; end
                  3: begin do_in_shift = 1; new_val = null; end
                  6: begin do_in_shift = 1; new_val = in_shift; end
                  7: begin do_in_shift = 1; new_val = out_shift; end
                endcase
          OUT:  if (auto_pull && osr_count >= osr_threshold) begin
                   pull = 1; new_val = din; set_shift_out = !empty; waiting = empty; auto = 1;
                end else case (op1) // Destination
                  0: begin do_out_shift = 1; new_val = out_shift; set_out_pins = 1; end                  // PINS
                  1: begin do_out_shift = 1; new_val = out_shift; setx = 1; end                          // X
                  2: begin do_out_shift = 1; new_val = out_shift; sety = 1; end                          // Y
                  4: begin do_out_shift = 1; new_val = out_shift; set_out_dirs = 1; end                  // PINDIRS
                  5: begin do_out_shift = 1; new_val = out_shift; jmp = 1; end                           // PC
                  6: begin do_out_shift = 1; new_val = out_shift; bit_count = op2; set_shift_in = 1; end // ISR
                  7: begin do_out_shift = 1; exec = 1; exec_instr = out_shift[15:0]; end                 // EXEC
                endcase
          PUSH: if (!op1[2]) begin // PUSH TODO Push IfFull
                  push = 1; 
                  dout = in_shift; 
                  set_shift_in = !(op1[0] && full);  
                  new_val = 0;
                  waiting = op1[0] && full;
                end else begin // PULL
                  if (op1[1]) begin // IfEmpty
                    if (osr_count >= osr_threshold) begin
                      pull = 1;
                      set_shift_out = !empty;
                      new_val = din;
                      waiting = empty;
                    end
                  end else begin
                    if (op1[0]) begin // Blocking
                      pull = 1; 
                      set_shift_out = !empty; 
                      waiting = empty;
                      new_val = din;
                    end else begin
                      if (empty) begin // Copy X to OSR
                        new_val = x;
                        set_shift_out = 1;
                      end else begin // Pull value if available
                        pull = 1;
                        new_val = din;
                        set_shift_out = 1;
                      end
                    end
                  end
                end
          MOV:  case (op1)  // Destination TODO Status source and pins
                  0: begin end // PINS
                  1: case (op2[2:0]) // X                                                    // X
                       2: begin new_val = bit_op(y, op2[4:3]); setx = 1; end                 // Y
                       3: begin new_val = bit_op(null, op2[4:3]); setx = 1; end              // NULL
                       6: begin new_val = bit_op(in_shift, op2[4:3]); setx = 1; end          // ISR
                       7: begin new_val = bit_op(out_shift, op2[4:3]); setx = 1; end         // OSR
                     endcase
                  2: case (op2[2:0]) // Y
                       1: begin new_val = bit_op(x, op2[4:3]); sety = 1; end                 // X
                       3: begin new_val = bit_op(null, op2[4:3]); sety = 1; end              // NULL
                       6: begin new_val = bit_op(in_shift, op2[4:3]); sety = 1; end          // ISR
                       6: begin new_val = bit_op(out_shift, op2[4:3]); sety = 1; end         // OSR
                     endcase
                  4: case (op2[2:0]) // EXEC
                       1: begin exec = 1; exec_instr = bit_op(x, op2[4:3]); end              // X
                       2: begin exec = 1; exec_instr = bit_op(y, op2[4:3]); end              // Y
                       3: begin exec = 1; exec_instr = bit_op(null, op2[4:3]); end           // NULL
                       6: begin exec = 1; exec_instr = bit_op(in_shift, op2[4:3]); end       // ISR
                       7: begin exec = 1; exec_instr = bit_op(out_shift, op2[4:3]); end      // OSR
                     endcase
                  5: case (op2[2:0]) // PC
                       1: begin new_val = bit_op(x, op2[4:3]); jmp = 1; end                   // X
                       2: begin new_val = bit_op(y, op2[4:3]); jmp = 1; end                   // Y
                       3: begin new_val = bit_op(null, op2[4:3]); jmp = 1; end                // NULL
                       6: begin new_val = bit_op(in_shift, op2[4:3]); jmp = 1; end            // ISR
                       7: begin new_val = bit_op(out_shift, op2[4:3]); jmp = 1; end           // OSR
                     endcase
                  6: case (op2[2:0]) // ISR
                       1: begin new_val = bit_op(x, op2[4:3]); set_shift_in = 1; end          // X
                       2: begin new_val = bit_op(y, op2[4:3]); set_shift_in = 1; end          // Y
                       3: begin new_val = bit_op(null, op2[4:3]); set_shift_in = 1; end       // NULL
                       6: begin new_val = bit_op(in_shift, op2[4:3]); set_shift_in = 1; end   // ISR
                       7: begin new_val = bit_op(out_shift, op2[4:3]); set_shift_in = 1; end  // OSR
                     endcase
                  7: case (op2[2:0]) // OSR
                       1: begin new_val = bit_op(x, op2[4:3]); set_shift_out = 1; end         // X
                       2: begin new_val = bit_op(y, op2[4:3]); set_shift_out = 1; end         // Y
                       3: begin new_val = bit_op(null, op2[4:3]); set_shift_out = 1; end      // NULL
                       6: begin new_val = bit_op(in_shift, op2[4:3]); set_shift_out = 1; end  // ISR
                       7: begin new_val = bit_op(out_shift, op2[4:3]); set_shift_out = 1; end // OSR
                     endcase
                endcase
          IRQ:  begin
                  if (op1[1]) irq_flags_out[irq_index] = 0;           // CLEAR
                  else begin
                    irq_flags_out[irq_index] = 1;
                    waiting = op1[0] && irq_flags_in[irq_index] != 0; // SET
                  end
                end
          SET:  case (op1) // Destination
                  0: set_set_pins = 1;                           // PINS
                  1: begin setx = 1; new_val = {27'b0, op2}; end // X
                  2: begin sety = 1; new_val = {27'b0, op2}; end // Y
                  4: set_set_dirs = 1;                           // PINDIRS
                endcase
        endcase
      end
  end

  // Clock divider
  divider clk_divider (
    .clk(clk),
    .reset(reset | restart),
    .div(div),
    .penable(penable)
  );

  // Instruction decoder
  decoder decode (
    .instr(exec1 ? exec1_instr : instr),
    .sideset_bits(sideset_bits),
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
    .stalled(delaying),
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
    .stalled(delaying),
    .dir(shift_dir),
    .shift(op2),
    .set(set_shift_out),
    .do_shift(do_out_shift),
    .din(new_val),
    .dout(out_shift),
    .shift_count(osr_count)
  );

endmodule

