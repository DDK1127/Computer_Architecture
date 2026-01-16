//========================================================================
// Lab 1 - Iterative Mul Unit 
//========================================================================

`ifndef RISCV_INT_MUL_ITERATIVE_V
`define RISCV_INT_MUL_ITERATIVE_V

//------------------------------------------------------------------------
// Top-level
//------------------------------------------------------------------------
module imuldiv_IntMulIterative
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

  // Datapath <-> Control 連接訊號
  wire [63:0] a_reg, result_reg;
  wire [31:0] b_reg;
  wire [5:0]  counter_reg;
  wire        sign_reg;

  wire        load;
  wire        a_shift_out,b_shift_out;
  wire        add_mux_out;

  wire        clear_result;
  wire        counter_decr, counter_load;
  wire        done;

  // Datapath
  imuldiv_IntMulIterativeDpath dpath (
    .clk(clk),
    .reset(reset),

    .mulreq_msg_a(mulreq_msg_a),
    .mulreq_msg_b(mulreq_msg_b),

    // .mulreq_val (mulreq_val), 
    // .mulreq_rdy (mulreq_rdy), 
    .mulresp_msg_result (mulresp_msg_result), 
    // .mulresp_val (mulresp_val), 
    // .mulresp_rdy (mulresp_rdy),

    .load(load),
    .a_shift_out(a_shift_out),
    .b_shift_out(b_shift_out),
    .add_mux_out(add_mux_out),
    .clear_result(clear_result),
    .counter_decr(counter_decr),
    .counter_load(counter_load),
    .done(done),

    .a_reg(a_reg),
    .b_reg(b_reg),
    .result_reg(result_reg),
    .counter_reg(counter_reg),
    .sign_reg(sign_reg)
  );

  // Control
  imuldiv_IntMulIterativeCtrl ctrl (
    .clk(clk),
    .reset(reset),

    .mulreq_val(mulreq_val),
    .mulreq_rdy(mulreq_rdy),
    .mulresp_val(mulresp_val),
    .mulresp_rdy(mulresp_rdy),

    .done(done),

    .load(load),
    .a_shift_out(a_shift_out),
    .b_shift_out(b_shift_out),
    .add_mux_out(add_mux_out),
    .clear_result(clear_result),
    .counter_decr(counter_decr),
    .counter_load(counter_load)
  );

endmodule


//------------------------------------------------------------------------
// Datapath
//------------------------------------------------------------------------
module imuldiv_IntMulIterativeDpath
(
  input         clk,
  input         reset,
  input  [31:0] mulreq_msg_a,
  input  [31:0] mulreq_msg_b,

  // input mulreq_val, // Request val Signal 
  // output mulreq_rdy, // Request rdy Signal
  // output mulresp_val, // Response val Signal 
  // input mulresp_rdy, // Response rdy Signal

  // control sign
  input         load,
  input         a_shift_out,
  inout         b_shift_out,
  input         add_mux_out,
  input         clear_result,
  input         counter_decr,
  input         counter_load,

  output reg [63:0] a_reg,
  output reg [31:0] b_reg,
  output reg [63:0] result_reg,
  output reg [5:0]  counter_reg,
  output reg        sign_reg,

  output            done,
  output [63:0]     mulresp_msg_result
);

  // Unsign operands if necessary
  wire [31:0] unsigned_a = (mulreq_msg_a[31]) ? (~mulreq_msg_a + 1'b1) : mulreq_msg_a;
  wire [31:0] unsigned_b = (mulreq_msg_b[31]) ? (~mulreq_msg_b + 1'b1) : mulreq_msg_b;
  // Extract sign bits
  wire        sign_bit   = mulreq_msg_a[31] ^ mulreq_msg_b[31];

  assign done = (counter_reg == 1);

  // 最後結果：根據 sign 決定是否取負
  assign mulresp_msg_result = (sign_reg) ? (~result_reg + 1'b1) : result_reg;

  always @(posedge clk) begin
    if (reset) begin
      a_reg      <= 0;
      b_reg      <= 0;
      result_reg <= 0;
      counter_reg<= 0;
      sign_reg   <= 0;
    end else begin
      if (load) begin
        a_reg      <= {32'b0, unsigned_a};
        b_reg      <= unsigned_b;
        sign_reg   <= sign_bit;
      end
      if (clear_result) begin
        result_reg <= 0;
      end
      if (add_mux_out && b_reg[0]) begin
        result_reg <= result_reg + a_reg;
      end
      if (a_shift_out) begin
        a_reg <= a_reg << 1;
      end
      if (b_shift_out) begin
        b_reg <= b_reg >> 1;
      end
      if (counter_load) begin
        counter_reg <= 6'd32;
      end else if (counter_decr) begin
        counter_reg <= counter_reg - 1'b1;
      end
    end
  end

  // assign mulreq_rdy = mulresp_rdy; 
  // assign mulresp_val = val_reg;

endmodule


//------------------------------------------------------------------------
// Control (FSM)
//------------------------------------------------------------------------
module imuldiv_IntMulIterativeCtrl
(
  input         clk,
  input         reset,

  input         mulreq_val,
  output reg    mulreq_rdy,
  output reg    mulresp_val,
  input         mulresp_rdy,
  
  input         done,

  output reg    load,
  output reg    a_shift_out, b_shift_out,
  output reg    add_mux_out,
  output reg    clear_result,
  output reg    counter_decr,
  output reg    counter_load
);

  localparam IDLE = 2'd0;
  localparam CALC = 2'd1;
  localparam RESP = 2'd2;

  reg [1:0] state, next_state;

  // state register
  always @(posedge clk) begin
    if (reset) state <= IDLE;
    else       state <= next_state;
  end

  // next cycle state & ouput logic
  always @(*) begin
    // init 
    mulreq_rdy    = 0;
    mulresp_val   = 0;
    load          = 0;
    a_shift_out   = 0;
    b_shift_out   = 0;
    add_mux_out   = 0;
    clear_result  = 0;
    counter_decr  = 0;
    counter_load  = 0;

    next_state = state;

    case (state)
      IDLE: begin
        mulreq_rdy = 1;
        if (mulreq_val) begin
          load         = 1;
          clear_result = 1;
          counter_load = 1;
          next_state   = CALC;
        end
      end

      CALC: begin
        add_mux_out = 1;   // each cycle do
        a_shift_out = 1;
        b_shift_out = 1;
        counter_decr = 1;
        if (done) next_state = RESP;
      end

      RESP: begin
        mulresp_val = 1;
        if (mulresp_rdy) next_state = IDLE;
      end
    endcase
  end

endmodule

`endif
