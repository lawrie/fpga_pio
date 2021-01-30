`default_nettype none
module machine (
  input         clk,
  input         reset,
  input         en,
  input [23:0]  div,
  input [31:0]  din,
  input [4:0]   pstart,
  input [4:0]   pend,
  input [15:0]  instr,
  input         jmp_pin,
  input [2:0]   sideset_bits,

  output [4:0]  pc,
  output reg    push,
  output reg    pull,
  output [31:0] dout
);
 
  reg         jmp;
  reg         setx;
  reg         sety;
  reg         decx;
  reg         decy;
  reg         wrap;
  reg [4:0]   index;
  reg         shift_dir;
  reg         set_shift;
  reg         waiting;
  reg [31:0]  new_val;
  
  wire        pclk;
  wire [4:0]  curr_pc;
  wire [31:0] x;
  wire [31:0] y;
  wire [31:0] in_shift;
  wire [31:0] out_shift;
  wire [2:0]  op;
  wire [4:0]  op1;
  wire [4:0]  op2;
  wire [4:0]  delay;
  reg [4:0]   delay1;
  reg [3:0]   sideset_count;

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
  always @(posedge pclk) begin
    if (en) begin
      jmp <= 0;
      pull <= 0;
      push <= 0;
      set_shift <= 0;
      decx <= 0;
      decy <= 0;
      waiting <= 0;
      setx <= 0;
      sety <= 0;
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
                0: waiting <= 1;
              endcase
        PULL: if (op1[2]) begin pull <= 1; set_shift <= 1; end
        IN:   case (op1)
                1: begin new_val <= in_shift; setx <= 1; end
              endcase
      endcase
    end
  end

  divider divider_inst (
    .clk(clk),
    .reset(reset),
    .div(div),
    .pclk(pclk)
  );

  pc pc_inst (
    .pclk(pclk),
    .reset(reset),
    .din(wrap ? index : op2),
    .jmp(jmp),
    .wrap(wrap),
    .dout(curr_pc)
  );

  scratch scratch_x (
    .pclk(pclk),
    .reset(reset),
    .din(new_val),
    .set(setx),
    .dec(decx),
    .dout(x)
  );

  scratch scratch_y (
    .pclk(pclk),
    .reset(reset),
    .din(new_val),
    .set(sety),
    .dec(decy),
    .dout(y)
  );

  decoder decoder_inst (
    .pclk(clk),
    .reset(reset),
    .instr(instr),
    .sideset_bits(sideset_bits),
    .op(op),
    .op1(op1),
    .op2(op2),
    .delay(delay)
  );

  shifter shift_in (
    .pclk(pclk),
    .reset(reset),
    .dir(shift_dir),
    .shift(op2),
    .din(din),
    .dout(in_shift)
  );

  shifter shift_out (
    .pclk(pclk),
    .reset(reset),
    .dir(shift_dir),
    .shift(op2),
    .set(set_shift),
    .din(din),
    .dout(out_shift)
  );

endmodule
 
