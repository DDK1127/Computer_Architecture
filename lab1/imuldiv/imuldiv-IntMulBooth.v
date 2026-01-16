//========================================================================
// Lab 1 - Booth Iterative Mul Unit
//========================================================================

`ifndef RISCV_INT_MUL_BOOTH_V
`define RISCV_INT_MUL_BOOTH_V

module imuldiv_IntMulBooth
(
  input         clk,
  input         reset,

  input  [31:0] mulreq_msg_a,
  input  [31:0] mulreq_msg_b,
  input         mulreq_val,
  output        mulreq_rdy,

  output [63:0] mulresp_msg_result,
  output        mulresp_val,
  input         mulresp_rdy
);

  // datapath <-> ctrl
  wire load, clear_result, counter_load, counter_decr;
  wire a_shift_out, b_shift_out, add_mux_out;
  wire done;

  wire [63:0] result_reg;

  imuldiv_IntMulBoothDpath dpath (
    .clk(clk),
    .reset(reset),
    .mulreq_msg_a(mulreq_msg_a),
    .mulreq_msg_b(mulreq_msg_b),

    .load(load),
    .clear_result(clear_result),
    .counter_load(counter_load),
    .counter_decr(counter_decr),
    .a_shift_out(a_shift_out),
    .b_shift_out(b_shift_out),
    .add_mux_out(add_mux_out),

    .result_reg(result_reg),
    .done(done)
  );

  assign mulresp_msg_result = result_reg;

  imuldiv_IntMulBoothCtrl ctrl (
    .clk(clk),
    .reset(reset),
    .mulreq_val(mulreq_val),
    .mulreq_rdy(mulreq_rdy),
    .mulresp_val(mulresp_val),
    .mulresp_rdy(mulresp_rdy),
    .done(done),

    .load(load),
    .clear_result(clear_result),
    .counter_load(counter_load),
    .counter_decr(counter_decr),
    .a_shift_out(a_shift_out),
    .b_shift_out(b_shift_out),
    .add_mux_out(add_mux_out)
  );

endmodule

//------------------------------------------------------------------------
// Datapath
//------------------------------------------------------------------------

module imuldiv_IntMulBoothDpath
(
  input         clk,
  input         reset,

  input  [31:0] mulreq_msg_a,
  input  [31:0] mulreq_msg_b,

  input         load,
  input         clear_result,
  input         counter_load,
  input         counter_decr,
  input         a_shift_out,
  input         b_shift_out,
  input         add_mux_out,

  output reg [63:0] result_reg,
  output            done
);

  reg [63:0] a_reg;
  reg [32:0] b_reg;      // 32 bits + guard bit
  reg [5:0]  counter;

  assign done = (counter == 6'd0);

  always @(posedge clk) begin
    if (reset) begin
      a_reg      <= 64'd0;
      b_reg      <= 33'd0;
      result_reg <= 64'd0;
      counter    <= 6'd0;
    end
    else begin
      if (load) begin
        a_reg      <= { {32{mulreq_msg_a[31]}}, mulreq_msg_a }; // sign extend
        b_reg      <= { mulreq_msg_b, 1'b0 };                   // guard bit
      end

      if (clear_result)
        result_reg <= 64'd0;

      if (counter_load)
        counter <= 6'd16;  // radix-4 needs 16 iterations
      else if (counter_decr && counter != 0)
        counter <= counter - 6'd1;

      if (add_mux_out && counter != 0) begin
        case (b_reg[2:0])
          3'b001, 3'b010: result_reg <= result_reg + a_reg;
          3'b011:         result_reg <= result_reg + (a_reg << 1);
          3'b100:         result_reg <= result_reg - (a_reg << 1);
          3'b101, 3'b110: result_reg <= result_reg - a_reg;
          default:        result_reg <= result_reg;
        endcase
      end

      if (a_shift_out && counter != 0)
        a_reg <= a_reg << 2;

      if (b_shift_out && counter != 0)
        b_reg <= b_reg >> 2;
    end
  end

endmodule

//------------------------------------------------------------------------
// Control Logic
//------------------------------------------------------------------------

module imuldiv_IntMulBoothCtrl
(
  input         clk,
  input         reset,

  input         mulreq_val,
  output reg    mulreq_rdy,
  output reg    mulresp_val,
  input         mulresp_rdy,

  input         done,

  output reg    load,
  output reg    clear_result,
  output reg    counter_load,
  output reg    counter_decr,
  output reg    a_shift_out,
  output reg    b_shift_out,
  output reg    add_mux_out
);

  localparam IDLE = 2'd0;
  localparam CALC = 2'd1;

  reg  [1:0] state, next_state;

  always @(posedge clk) begin
    if (reset) state <= IDLE;
    else       state <= next_state;
  end

  always @(*) begin
    // default
    mulreq_rdy    = 0;
    mulresp_val   = 0;
    load          = 0;
    clear_result  = 0;
    counter_load  = 0;
    counter_decr  = 0;
    a_shift_out   = 0;
    b_shift_out   = 0;
    add_mux_out   = 0;

    next_state = state;

    case (state)
      IDLE: begin
        mulreq_rdy = 1;
        if (mulreq_val) begin
          load          = 1;
          clear_result  = 1;
          counter_load  = 1;
          next_state    = CALC;
        end
      end

      CALC: begin
        if (!done) begin
          add_mux_out  = 1;
          a_shift_out  = 1;
          b_shift_out  = 1;
          counter_decr = 1;
        end else begin
          mulresp_val = 1;
          if (mulresp_rdy) next_state = IDLE;
        end
      end
    endcase
  end

endmodule

`endif
