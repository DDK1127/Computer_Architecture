//========================================================================
// Lab 1 - Iterative Div Unit (分 Datapath / Control) 
// 輸出格式： { remainder[31:0], quotient[31:0] }
//========================================================================

`ifndef RISCV_INT_DIV_ITERATIVE_V
`define RISCV_INT_DIV_ITERATIVE_V

`include "imuldiv-DivReqMsg.v"

module imuldiv_IntDivIterative
(
  input         clk,
  input         reset,

  input         divreq_msg_fn,   // function: signed / unsigned (macro 定義)
  input  [31:0] divreq_msg_a,    // dividend
  input  [31:0] divreq_msg_b,    // divisor
  input         divreq_val,
  output        divreq_rdy,

  output [63:0] divresp_msg_result,
  output        divresp_val,
  input         divresp_rdy
);

  // Datapath <-> Control signals
  wire        load;
  wire        clear_regs;
  wire        sub_mux;
  wire        counter_load;
  wire        counter_decr;

  wire [31:0] quotient_reg;
  wire [31:0] remainder_reg;
  wire [31:0] divisor_reg;
  wire [31:0] dividend_reg;
  wire [5:0]  counter_reg;
  wire        done;

  // (optional) sign info from datapath
  wire        sign_q;
  wire        sign_r;

  // Datapath
  imuldiv_IntDivIterativeDpath dpath (
    .clk(clk),
    .reset(reset),

    .divreq_msg_fn(divreq_msg_fn),
    .divreq_msg_a(divreq_msg_a),
    .divreq_msg_b(divreq_msg_b),

    .load(load),
    .clear_regs(clear_regs),
    .sub_mux(sub_mux),
    .counter_load(counter_load),
    .counter_decr(counter_decr),

    .quotient_reg(quotient_reg),
    .remainder_reg(remainder_reg),
    .divisor_reg(divisor_reg),
    .dividend_reg(dividend_reg),
    .counter_reg(counter_reg),
    .done(done),

    .sign_q(sign_q),
    .sign_r(sign_r),

    .divresp_msg_result(divresp_msg_result)
  );

  // Control
  imuldiv_IntDivIterativeCtrl ctrl (
    .clk(clk),
    .reset(reset),

    .divreq_val(divreq_val),
    .divreq_rdy(divreq_rdy),
    .divresp_val(divresp_val),
    .divresp_rdy(divresp_rdy),

    .counter_reg(counter_reg),
    .done(done),

    .load(load),
    .clear_regs(clear_regs),
    .sub_mux(sub_mux),
    .counter_load(counter_load),
    .counter_decr(counter_decr)
  );

endmodule


//------------------------------------------------------------------------
// Datapath (iterative restoring-like divider)
//------------------------------------------------------------------------
module imuldiv_IntDivIterativeDpath
(
  input         clk,
  input         reset,

  input         divreq_msg_fn,   // signed / unsigned macro
  input  [31:0] divreq_msg_a,
  input  [31:0] divreq_msg_b,

  // control
  input         load,
  input         clear_regs,
  input         sub_mux,
  input         counter_load,
  input         counter_decr,

  // status outputs
  output reg [31:0] quotient_reg,
  output reg [31:0] remainder_reg,
  output reg [31:0] divisor_reg,
  output reg [31:0] dividend_reg,
  output reg [5:0]  counter_reg,
  output            done,

  // sign markers (可選 debug/外部使用)
  output reg        sign_q,
  output reg        sign_r,

  // packed final result
  output [63:0] divresp_msg_result
);

  // sign bits from input (used only on load)
  wire sign_a = divreq_msg_a[31];
  wire sign_b = divreq_msg_b[31];

  // absolute values (combinational)
  wire [31:0] abs_a = (sign_a) ? (~divreq_msg_a + 1'b1) : divreq_msg_a;
  wire [31:0] abs_b = (sign_b) ? (~divreq_msg_b + 1'b1) : divreq_msg_b;

  assign done = (counter_reg == 1);

  // rem_tmp and subtraction as combinational wires (避免在時脈 block 用 blocking)
  // rem_tmp = (remainder << 1) | dividend[31]
  wire [32:0] rem_tmp_ext = { remainder_reg, dividend_reg[31] };
  // subtraction result
  wire [32:0] sub_res_ext = rem_tmp_ext - {1'b0, divisor_reg};

  // decide loaded_divisor (unsigned absolute when signed op)
  wire [31:0] loaded_divisor = (divreq_msg_fn == `IMULDIV_DIVREQ_MSG_FUNC_SIGNED) ? abs_b : divreq_msg_b;
  wire [31:0] loaded_dividend = (divreq_msg_fn == `IMULDIV_DIVREQ_MSG_FUNC_SIGNED) ? abs_a : divreq_msg_a;

  always @(posedge clk) begin
    if (reset) begin
      quotient_reg  <= 32'd0;
      remainder_reg <= 32'd0;
      divisor_reg   <= 32'd0;
      dividend_reg  <= 32'd0;
      counter_reg   <= 6'd0;
      sign_q        <= 1'b0;
      sign_r        <= 1'b0;
    end else begin
      // LOAD: capture operands (absolute if signed) and set initial state
      if (load) begin
        // store operands (unsigned form for algorithm)
        dividend_reg <= loaded_dividend;
        divisor_reg  <= loaded_divisor;

        // sign markers for later correction (only meaningful for signed op)
        if (divreq_msg_fn == `IMULDIV_DIVREQ_MSG_FUNC_SIGNED) begin
          sign_q <= sign_a ^ sign_b; // quotient sign
          sign_r <= sign_a;          // remainder sign follows dividend
        end else begin
          sign_q <= 1'b0;
          sign_r <= 1'b0;
        end

        // div-by-zero handling: immediate result, counter = 0 (done)
        if (loaded_divisor == 32'd0) begin
          quotient_reg  <= 32'hFFFF_FFFF;      // common convention: quotient = all 1s
          remainder_reg <= loaded_dividend;    // remainder = dividend (will be signed later if needed)
          counter_reg   <= 6'd0;               // immediately done
        end else begin
          quotient_reg  <= 32'd0;
          remainder_reg <= 32'd0;
          counter_reg   <= 6'd32;              // start 32 iterations
        end
      end else begin
        // clear_regs support (if control wants to explicitly clear)
        if (clear_regs) begin
          quotient_reg  <= 32'd0;
          remainder_reg <= 32'd0;
        end

        // normal counter update (control may assert counter_decr each iter)
        if (counter_load) begin
          counter_reg <= 6'd32;
        end else if (counter_decr) begin
          counter_reg <= counter_reg - 1'b1;
        end

        // iteration step: do one bit when sub_mux asserted and counter not zero
        if (sub_mux && (counter_reg != 6'd0)) begin
          // shift dividend left by 1 (bring next bit into MSB)
          dividend_reg <= dividend_reg << 1;

          // check subtraction result (sub_res_ext[32] == 0 means rem_tmp >= divisor)
          if (sub_res_ext[32] == 1'b0) begin
            remainder_reg <= sub_res_ext[31:0];
            quotient_reg  <= (quotient_reg << 1) | 1'b1;
          end else begin
            remainder_reg <= rem_tmp_ext[31:0];
            quotient_reg  <= (quotient_reg << 1);
          end
        end
      end
    end
  end

  // sign restoration for output (combinational)
  wire [31:0] out_quotient_signed = (sign_q) ? (~quotient_reg + 1'b1) : quotient_reg;
  wire [31:0] out_remainder_signed = (sign_r) ? (~remainder_reg + 1'b1) : remainder_reg;

  assign divresp_msg_result = { out_remainder_signed, out_quotient_signed };

endmodule


//------------------------------------------------------------------------
// Control FSM 
//------------------------------------------------------------------------
module imuldiv_IntDivIterativeCtrl
(
  input         clk,
  input         reset,

  input         divreq_val,
  output reg    divreq_rdy,
  output reg    divresp_val,
  input         divresp_rdy,

  input  [5:0]  counter_reg,
  input         done,

  output reg    load,
  output reg    clear_regs,
  output reg    sub_mux,
  output reg    counter_load,
  output reg    counter_decr
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

  // next-state & outputs
  always @(*) begin
    // defaults
    divreq_rdy   = 1'b0;
    divresp_val  = 1'b0;
    load         = 1'b0;
    clear_regs   = 1'b0;
    sub_mux      = 1'b0;
    counter_load = 1'b0;
    counter_decr = 1'b0;
    next_state   = state;

    case (state)
      IDLE: begin
        divreq_rdy = 1'b1;
        // accept only when downstream can accept response to avoid overflow
        if (divreq_val && divresp_rdy) begin
          load         = 1'b1;
          clear_regs   = 1'b1;
          counter_load = 1'b1; // datapath will set counter=32, or 0 if divisor==0
          next_state   = CALC;
        end
      end

      CALC: begin
        // 每個 cycle 做一位
        sub_mux      = 1'b1;
        counter_decr = 1'b1;
        if (done) next_state = RESP;
      end

      RESP: begin
        divresp_val = 1'b1;
        if (divresp_rdy) next_state = IDLE;
      end
    endcase
  end

endmodule

`endif
