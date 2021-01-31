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

  reg         waiting = 0;
  reg [31:0]  new_val;
  reg [3:0]   sideset_count;
 
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

  reg [4:0] delay_cnt = 0;

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

  // Execute the current instruction
  always @(posedge clk) begin
    if (reset) begin
      delay_cnt <= 0;
    end else if (en & penable) begin // Machine enabled and divided clock enabled
      jmp <= 0;
      pull <= 0;
      push <= 0;
      set_shift <= 0;
      decx <= 0;
      decy <= 0;
      setx <= 0;
      sety <= 0;
      delay_cnt <= delay;
      if (delay_cnt > 0) delay_cnt <= delay_cnt - 1;
      else begin
        case (op)
          JMP:  case (op1)
                  0: jmp <= 1;
                  1: jmp <= (x == 0);
                  2: begin jmp <= (x != 0); decx <= 1; end
                  3: jmp <= (y == 0);
                  4: begin jmp <= (y != 0); decy <= 1; end
                  5: jmp <= (x != y);
                  6: jmp <= jmp_pin;
                  7: jmp <= (out_shift != 0);
                endcase
	  WAIT: case (op1[1:0])
                  0: waiting <= gpio_pins[op2] != op1[2];
                  1: waiting <= input_pins[op2] != op1[2];
                  2: waiting <= irq_flags[op2] != op1[2];
                endcase
          PULL: if (op1[2]) begin pull <= 1; set_shift <= 1; end
          IN:   case (op1)
                  1: begin new_val <= in_shift; setx <= 1; end
                endcase
          SET:  case (op1)
                  0: begin
                       if (pins_set_count > 4) output_pins[pins_set_base+4] <= op2[4];
                       if (pins_set_count > 3) output_pins[pins_set_base+3] <= op2[3];
                       if (pins_set_count > 2) output_pins[pins_set_base+2] <= op2[2];
                       if (pins_set_count > 1) output_pins[pins_set_base+1] <= op2[1];
                       if (pins_set_count > 0) output_pins[pins_set_base+0] <= op2[0];
                     end
                  1: begin setx <= 1; new_val <= {27'b0, op2}; end
                  2: begin sety <= 1; new_val <= {27'b0, op2}; end
                  4: begin
                       if (pins_set_count > 4) pin_directions[pins_set_base+4] <= op2[4];
                       if (pins_set_count > 3) pin_directions[pins_set_base+3] <= op2[3];
                       if (pins_set_count > 2) pin_directions[pins_set_base+2] <= op2[2];
                       if (pins_set_count > 1) pin_directions[pins_set_base+1] <= op2[1];
                       if (pins_set_count > 0) pin_directions[pins_set_base+0] <= op2[0];
                     end
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
    .penable(penable),
    .reset(reset),
    .din(op2),
    .jmp(jmp),
    .stalled(waiting || imm || delay_cnt > 0),
    .pend(pend),
    .dout(pc)
  );

  scratch scratch_x (
    .clk(clk),
    .penable(penable),
    .reset(reset),
    .din(new_val),
    .set(setx),
    .dec(decx),
    .dout(x)
  );

  scratch scratch_y (
    .clk(clk),
    .penable(penable),
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
    .delay(delay)
  );

  shifter shift_in (
    .clk(clk),
    .penable(penable),
    .reset(reset),
    .dir(shift_dir),
    .shift(op2),
    .din(din),
    .dout(in_shift)
  );

  shifter shift_out (
    .clk(clk),
    .penable(penable),
    .reset(reset),
    .dir(shift_dir),
    .shift(op2),
    .set(set_shift),
    .din(din),
    .dout(out_shift)
  );

endmodule
 
