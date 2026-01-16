//========================================================================
// Lab 1 - Iterative Mul/Div Unit 
//========================================================================

`ifndef RISCV_INT_MULDIV_ITERATIVE_V
`define RISCV_INT_MULDIV_ITERATIVE_V

`include "imuldiv-MulDivReqMsg.v"
`include "imuldiv-IntMulIterative.v"
`include "imuldiv-IntDivIterative.v"

module imuldiv_IntMulDivIterative
(
  input         clk,
  input         reset,

  input   [2:0] muldivreq_msg_fn,   // 3-bit: {MUL,MULH,MULHU,MULHSU,DIV,DIVU,REM,REMU}
  input  [31:0] muldivreq_msg_a,
  input  [31:0] muldivreq_msg_b,
  input         muldivreq_val,
  output        muldivreq_rdy,

  output [63:0] muldivresp_msg_result,
  output        muldivresp_val,
  input         muldivresp_rdy
);

  // -----------------------------
  // Classify op
  // -----------------------------
  wire is_mul =
       (muldivreq_msg_fn == `IMULDIV_MULDIVREQ_MSG_FUNC_MUL   ) ||
       (muldivreq_msg_fn == `IMULDIV_MULDIVREQ_MSG_FUNC_MULH  ) ||
       (muldivreq_msg_fn == `IMULDIV_MULDIVREQ_MSG_FUNC_MULHU ) ||
       (muldivreq_msg_fn == `IMULDIV_MULDIVREQ_MSG_FUNC_MULHSU);

  wire is_div =
       (muldivreq_msg_fn == `IMULDIV_MULDIVREQ_MSG_FUNC_DIV   ) ||
       (muldivreq_msg_fn == `IMULDIV_MULDIVREQ_MSG_FUNC_DIVU  ) ||
       (muldivreq_msg_fn == `IMULDIV_MULDIVREQ_MSG_FUNC_REM   ) ||
       (muldivreq_msg_fn == `IMULDIV_MULDIVREQ_MSG_FUNC_REMU  );

  // -----------------------------
  // Map to 2-bit mul fn
  //   2'b00 = MUL (low32)
  //   2'b01 = MULH (s*s high32)
  //   2'b10 = MULHSU (s*u high32)
  //   2'b11 = MULHU (u*u high32)
  // -----------------------------
  localparam [1:0] MULFN_MUL    = 2'b00;
  localparam [1:0] MULFN_MULH   = 2'b01;
  localparam [1:0] MULFN_MULHSU = 2'b10;
  localparam [1:0] MULFN_MULHU  = 2'b11;

  wire [1:0] mulreq_msg_fn_2b =
      (muldivreq_msg_fn == `IMULDIV_MULDIVREQ_MSG_FUNC_MUL   ) ? MULFN_MUL    :
      (muldivreq_msg_fn == `IMULDIV_MULDIVREQ_MSG_FUNC_MULH  ) ? MULFN_MULH   :
      (muldivreq_msg_fn == `IMULDIV_MULDIVREQ_MSG_FUNC_MULHSU) ? MULFN_MULHSU :
                                                                 MULFN_MULHU; 

  wire        mulreq_rdy, divreq_rdy;
  wire        mulresp_val, divresp_val;
  wire [63:0] mulresp_msg_result, divresp_msg_result;

  wire mulreq_val = (is_mul && muldivreq_val && divreq_rdy);
  wire divreq_val = (is_div && muldivreq_val && mulreq_rdy);

  assign muldivreq_rdy = mulreq_rdy && divreq_rdy;

  assign muldivresp_val        = mulresp_val || divresp_val;
  assign muldivresp_msg_result = mulresp_val ? mulresp_msg_result
                                            : divresp_msg_result;

  imuldiv_IntMulIterative imul (
    .clk(clk), .reset(reset),
    .mulreq_msg_a(muldivreq_msg_a),
    .mulreq_msg_b(muldivreq_msg_b),
    .mulreq_msg_fn(mulreq_msg_fn_2b), // 2-bit
    .mulreq_val(mulreq_val), .mulreq_rdy(mulreq_rdy),
    .mulresp_msg_result(mulresp_msg_result),
    .mulresp_val(mulresp_val), .mulresp_rdy(muldivresp_rdy)
  );

  wire div_signed =
      (muldivreq_msg_fn == `IMULDIV_MULDIVREQ_MSG_FUNC_DIV) ||
      (muldivreq_msg_fn == `IMULDIV_MULDIVREQ_MSG_FUNC_REM);

  imuldiv_IntDivIterative idiv (
    .clk(clk), .reset(reset),
    .divreq_msg_fn(div_signed),
    .divreq_msg_a(muldivreq_msg_a),
    .divreq_msg_b(muldivreq_msg_b),
    .divreq_val(divreq_val), .divreq_rdy(divreq_rdy),
    .divresp_msg_result(divresp_msg_result),
    .divresp_val(divresp_val), .divresp_rdy(muldivresp_rdy)
  );

endmodule

`endif
