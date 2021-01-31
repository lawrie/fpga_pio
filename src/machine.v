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
  input [31:0]  irq_flags,
  input         imm,
  input         empty,
  input         full,

  // Configuration
  input [1:0]   mindex,
  input [4:0]   pstart,
  input [4:0]   pend,
  input         jmp_pin,
  input [2:0]   sideset_bits,
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

  // Output
  output [4:0]  pc,
  output reg    push, // Send data to output FIFO
  output reg    pull, // Get data from input FIFO
  output [31:0] dout,
  output reg [31:0] output_pins,
  output reg [31:0] pin_directions
);

  // Strobes to implement instructions 
  reg         jmp;
  reg         setx;
  reg         sety;
  reg         decx;
  reg         decy;
  reg         set_shift;
  reg         do_shift;
  reg         set_set_pins;
  reg         set_set_dirs;

  reg         waiting = 0;
  reg [31:0]  new_val;
 
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

  reg [4:0] delay_cnt = 0;

  function [31:0] reverse (
    input [31:0] in
  );

    integer i;
    for(i=0;i<32;i=i+1) begin
      reverse[i] = in[31-i];
    end
  endfunction

  function [31:0] bit_op (
    input [31:0] in,
    input [1:0] op
  );

    case (op) 
      0: bit_op = in;
      1: bit_op = ~in;
      2: bit_op = reverse(in);
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

  // Count down if delay, and set pins
  always @(posedge clk) begin
    if (en & penable) begin
      if (delay_cnt > 0) delay_cnt <= delay_cnt - 1;
      else if (!waiting) delay_cnt <= delay;
      if (sideset_bits > 0) begin
        if (pins_side_count > 4) output_pins[pins_side_base+4] = side_set[4];
        if (pins_side_count > 3) output_pins[pins_side_base+3] = side_set[3];
        if (pins_side_count > 2) output_pins[pins_side_base+2] = side_set[2];
        if (pins_side_count > 1) output_pins[pins_side_base+1] = side_set[1];
        if (pins_side_count > 0) output_pins[pins_side_base+0] = side_set[0];
      end
      if (set_set_pins) begin
         if (pins_set_count > 4) output_pins[pins_set_base+4] = op2[4];
         if (pins_set_count > 3) output_pins[pins_set_base+3] = op2[3];
         if (pins_set_count > 2) output_pins[pins_set_base+2] = op2[2];
         if (pins_set_count > 1) output_pins[pins_set_base+1] = op2[1];
         if (pins_set_count > 0) output_pins[pins_set_base+0] = op2[0];
       end
       if (set_set_dirs) begin
         if (pins_set_count > 4) pin_directions[pins_set_base+4] = op2[4];
         if (pins_set_count > 3) pin_directions[pins_set_base+3] = op2[3];
         if (pins_set_count > 2) pin_directions[pins_set_base+2] = op2[2];
         if (pins_set_count > 1) pin_directions[pins_set_base+1] = op2[1];
         if (pins_set_count > 0) pin_directions[pins_set_base+0] = op2[0];
       end
    end
  end
  
  // Execute the current instruction
  always @* begin
    begin
      jmp  = 0;
      pull = 0;
      push = 0;
      set_shift = 0;
      do_shift = 0;
      decx = 0;
      decy = 0;
      setx = 0;
      sety = 0;
      waiting = 0;
      new_val = 0;
      set_set_pins = 0;
      set_set_dirs = 0;
      begin
        case (op)
          JMP:  begin
                  new_val[4:0] = op2; 
                  case (op1)
                    0: jmp = 1;
                    1: jmp = (x == 0);
                    2: begin jmp = (x != 0); decx = 1; end
                    3: jmp = (y == 0);
                    4: begin jmp = (y != 0); decy = 1; end
                    5: jmp = (x != y);
                    6: jmp = jmp_pin;
                    7: jmp = (out_shift != 0);
                  endcase
                end
	  WAIT: case (op1[1:0])
                  0: waiting = gpio_pins[op2] != op1[2];
                  1: waiting = input_pins[op2] != op1[2];
                  2: waiting = irq_flags[op2] != op1[2];
                endcase
          IN:   case (op1)
                  1: begin new_val = in_shift; setx = 1; end
                endcase
          OUT:  case (op1)
                  0: begin end // Pins
                  1: begin do_shift = 1; new_val = out_shift; setx = 1; end // X
                  2: begin end // Y
                  4: begin end // Pindirs
                  5: begin end // PC
                endcase
          PUSH: if (!op1[2]) begin end                                               // Push
                else begin pull <= 1; set_shift <= 1; waiting <= op[0] && empty; end // Pull
          MOV:  case (op1)
                  0: begin end // Pins
                  1: case (op2[2:0]) // X
                       2: begin new_val = bit_op(y, op2[4:3]); setx = 1; end // Y
                     endcase
                  2: case (op2[2:0]) // Y
                       1: begin new_val = bit_op(x, op2[4:3]); sety = 1; end // X
                     endcase
                  4: begin end // Exec
                  5: case (op2[2:0]) // PC
                       1: begin new_val = bit_op(x, op2[4:3]); jmp = 1; end // X
                       2: begin new_val = bit_op(y, op2[4:3]); jmp = 1; end // Y
                     endcase
                  6: begin end // ISR
                  7: begin end // OSR
                endcase
          IRQ:  begin end
          SET:  case (op1)
                  0: set_set_pins = 1;
                  1: begin setx = 1; new_val = {27'b0, op2}; end
                  2: begin sety = 1; new_val = {27'b0, op2}; end
                  4: set_set_dirs = 1;
                endcase
        endcase
      end
    end
  end

  divider clk_divider (
    .clk(clk),
    .reset(reset),
    .div(div),
    .penable(penable)
  );

  pc pc_reg (
    .clk(clk),
    .penable(en & penable),
    .reset(reset),
    .din(new_val[4:0]),
    .jmp(jmp),
    .stalled(waiting || imm || delay_cnt > 0),
    .pend(pend),
    .dout(pc)
  );

  scratch scratch_x (
    .clk(clk),
    .penable(en & penable),
    .reset(reset),
    .din(new_val),
    .set(setx),
    .dec(decx),
    .dout(x)
  );

  scratch scratch_y (
    .clk(clk),
    .penable(en & penable),
    .reset(reset),
    .din(new_val),
    .set(sety),
    .dec(decy),
    .dout(y)
  );

  decoder decoder_inst (
    .instr(instr),
    .sideset_bits(sideset_bits),
    .op(op),
    .op1(op1),
    .op2(op2),
    .delay(delay),
    .side_set(side_set)
  );

  shifter shift_in (
    .clk(clk),
    .penable(en & penable),
    .reset(reset),
    .dir(shift_dir),
    .shift(op2),
    .din(din),
    .dout(in_shift)
  );

  shifter shift_out (
    .clk(clk),
    .penable(en & penable),
    .reset(reset),
    .dir(shift_dir),
    .shift(op2),
    .set(set_shift),
    .do_shift(do_shift),
    .din(din),
    .dout(out_shift)
  );

endmodule
 
