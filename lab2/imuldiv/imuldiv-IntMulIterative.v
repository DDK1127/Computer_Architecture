//========================================================================
// Lab 1 - Iterative Mul Unit (MUL / MULH / MULHU / MULHSU)
//========================================================================

`ifndef RISCV_INT_MUL_ITERATIVE_V
`define RISCV_INT_MUL_ITERATIVE_V

module imuldiv_IntMulIterative
(
  input                clk,
  input                reset,

  input  [31:0] mulreq_msg_a,
  input  [31:0] mulreq_msg_b,
  input  [1:0]  mulreq_msg_fn,   // opcode

  input         mulreq_val,
  output        mulreq_rdy,

  output [63:0] mulresp_msg_result, 
  output        mulresp_val,
  input         mulresp_rdy
);

  // ctrl -> datapath
  wire    [4:0] counter;
  wire          sign;
  wire          b_lsb;
  wire          sign_en;
  wire          result_en;
  wire          cntr_mux_sel;
  wire          a_mux_sel;
  wire          b_mux_sel;
  wire          result_mux_sel;
  wire          add_mux_sel;

  imuldiv_IntMulIterativeDpath dpath
  (
    .clk                (clk),
    .reset              (reset),
    .mulreq_msg_a       (mulreq_msg_a),
    .mulreq_msg_b       (mulreq_msg_b),
    .mulreq_msg_fn      (mulreq_msg_fn),
    .mulresp_msg_result (mulresp_msg_result),
    .counter            (counter),
    .sign               (sign),
    .b_lsb              (b_lsb),
    .sign_en            (sign_en),
    .result_en          (result_en),
    .cntr_mux_sel       (cntr_mux_sel),
    .a_mux_sel          (a_mux_sel),
    .b_mux_sel          (b_mux_sel),
    .result_mux_sel     (result_mux_sel),
    .add_mux_sel        (add_mux_sel)
  );

  imuldiv_IntMulIterativeCtrl ctrl
  (
    .clk            (clk),
    .reset          (reset),
    .mulreq_val     (mulreq_val),
    .mulreq_rdy     (mulreq_rdy),
    .mulresp_val    (mulresp_val),
    .mulresp_rdy    (mulresp_rdy),
    .counter        (counter),
    .sign           (sign),
    .b_lsb          (b_lsb),
    .sign_en        (sign_en),
    .result_en      (result_en),
    .cntr_mux_sel   (cntr_mux_sel),
    .a_mux_sel      (a_mux_sel),
    .b_mux_sel      (b_mux_sel),
    .result_mux_sel (result_mux_sel),
    .add_mux_sel    (add_mux_sel)
  );

endmodule

//------------------------------------------------------------------------
// Datapath
//------------------------------------------------------------------------

module imuldiv_IntMulIterativeDpath
(
  input                clk,
  input                reset,

  input  [31:0] mulreq_msg_a,
  input  [31:0] mulreq_msg_b,
  input  [1:0]  mulreq_msg_fn,

  output [63:0] mulresp_msg_result,

  output  [4:0] counter,
  output        sign,
  output        b_lsb,

  input         sign_en,
  input         result_en,
  input         cntr_mux_sel,
  input         a_mux_sel,
  input         b_mux_sel,
  input         result_mux_sel,
  input         add_mux_sel
);

  //--------------------------------------------------------------------
  // setup
  //--------------------------------------------------------------------
  localparam op_load  = 1'b0;
  localparam op_next  = 1'b1;
  localparam add_old  = 1'b0;
  localparam add_next = 1'b1;

  // fn code
  localparam [1:0] FN_MUL    = 2'd0; // signed*signed, low 32
  localparam [1:0] FN_MULH   = 2'd1; // signed*signed, high 32
  localparam [1:0] FN_MULHSU = 2'd2; // signed*unsigned, high 32
  localparam [1:0] FN_MULHU  = 2'd3; // unsigned*unsigned, high 32

  //--------------------------------------------------------------------
  // Counter
  //--------------------------------------------------------------------
  reg  [4:0] counter_reg;
  assign counter = counter_reg;
  wire [4:0] counter_mux_out =
      (cntr_mux_sel==op_load) ? 5'd31 :
      (cntr_mux_sel==op_next) ? (counter_reg - 1'b1) :
                                 counter_reg;

  //--------------------------------------------------------------------
  // Sign and input processing
  //--------------------------------------------------------------------
  wire [31:0] a_abs = mulreq_msg_a[31] ? (~mulreq_msg_a + 1'b1) : mulreq_msg_a;
  wire [31:0] b_abs = mulreq_msg_b[31] ? (~mulreq_msg_b + 1'b1) : mulreq_msg_b;

  reg [63:0] opa_in;   // high 32 bits + low 32 bits
  reg [31:0] opb_in;   // low 32 bits
  reg        sign_next;

  always @(*) begin
    case (mulreq_msg_fn)
      FN_MUL: begin
        opa_in    = {32'b0, a_abs};
        opb_in    = b_abs;
        sign_next = mulreq_msg_a[31] ^ mulreq_msg_b[31];
      end
      FN_MULH: begin
        opa_in    = {32'b0, a_abs};
        opb_in    = b_abs;
        sign_next = mulreq_msg_a[31] ^ mulreq_msg_b[31];
      end
      FN_MULHU: begin
        opa_in    = {32'b0, mulreq_msg_a};
        opb_in    = mulreq_msg_b;     // unsigned 
        sign_next = 1'b0;             // unsigned
      end
      FN_MULHSU: begin
        opa_in    = {32'b0, a_abs};
        opb_in    = mulreq_msg_b;     // unsigned
        sign_next = mulreq_msg_a[31]; // decided by rs1 (signed), bcs s2 is unsigned.
      end
      default: begin
        opa_in    = 64'b0;
        opb_in    = 32'b0;
        sign_next = 1'b0;
      end
    endcase
  end

  reg sign_reg;
  assign sign = sign_reg;

  //--------------------------------------------------------------------
  // Calculate
  //--------------------------------------------------------------------
  reg [63:0] a_reg;
  reg [31:0] b_reg;
  reg [63:0] result_reg;

  wire [63:0] a_mux_out =
      (a_mux_sel==op_load) ? opa_in :
      (a_mux_sel==op_next) ? (a_reg << 1) :
                              a_reg;

  wire [31:0] b_mux_out =
      (b_mux_sel==op_load) ? opb_in :
      (b_mux_sel==op_next) ? (b_reg >> 1) :
                              b_reg;

  wire [63:0] add_out = result_reg + a_reg;
  wire [63:0] add_mux_out =
      (add_mux_sel==add_old)  ? result_reg :
      (add_mux_sel==add_next) ? add_out    :
                                result_reg;

  wire [63:0] result_mux_out =
      (result_mux_sel==op_load) ? 64'b0 :
      (result_mux_sel==op_next) ? add_mux_out :
                                  result_reg;

  always @(posedge clk) begin
    if (reset) begin
      counter_reg <= 0;
      sign_reg    <= 0;
      a_reg       <= 0;
      b_reg       <= 0;
      result_reg  <= 0;
    end
    else begin
      counter_reg <= counter_mux_out;
      a_reg       <= a_mux_out;
      b_reg       <= b_mux_out;
      if (sign_en)   sign_reg   <= sign_next;
      if (result_en) result_reg <= result_mux_out;
    end
  end

  assign b_lsb = b_reg[0];

  //--------------------------------------------------------------------
  // output result
  //--------------------------------------------------------------------
  wire [63:0] unsigned_result = result_reg;
  wire [63:0] signed_result   = sign ? (~result_reg + 64'b1) : result_reg;

  assign mulresp_msg_result =
      (mulreq_msg_fn==FN_MUL)    ? signed_result   :
      (mulreq_msg_fn==FN_MULH)   ? signed_result   :
      (mulreq_msg_fn==FN_MULHSU) ? signed_result   :
      (mulreq_msg_fn==FN_MULHU)  ? unsigned_result :
                                   64'b0;

endmodule

//------------------------------------------------------------------------
// Control Logic
//------------------------------------------------------------------------

module imuldiv_IntMulIterativeCtrl
(
  input        clk,
  input        reset,

  input        mulreq_val,
  output       mulreq_rdy,

  output       mulresp_val,
  input        mulresp_rdy,

  input  [4:0] counter,
  input        sign,
  input        b_lsb,

  output       sign_en,
  output       result_en,
  output       cntr_mux_sel,
  output       a_mux_sel,
  output       b_mux_sel,
  output       result_mux_sel,
  output       add_mux_sel
);

  localparam STATE_IDLE = 2'd0;
  localparam STATE_CALC = 2'd1;
  localparam STATE_SIGN = 2'd2;

  reg [1:0] state_reg, state_next;
  always @(posedge clk) begin
    if (reset)
      state_reg <= STATE_IDLE;
    else
      state_reg <= state_next;
  end

  wire mulreq_go    = mulreq_val && mulreq_rdy;
  wire mulresp_go   = mulresp_val && mulresp_rdy;
  wire is_calc_done = (counter == 5'b0);

  always @(*) begin
    state_next = state_reg;
    case (state_reg)
      STATE_IDLE: if (mulreq_go)    state_next = STATE_CALC;
      STATE_CALC: if (is_calc_done) state_next = STATE_SIGN;
      STATE_SIGN: if (mulresp_go)   state_next = STATE_IDLE;
    endcase
  end

  localparam n=1'b0, y=1'b1;
  localparam op_load=1'b0, op_next=1'b1;

  localparam cs_size=8;
  reg [cs_size-1:0] cs;

  always @(*) begin
    case (state_reg)
      //               mulreq mulresp sign result cntr    a       b       result
      STATE_IDLE: cs = { y,     n,     y,   y,    op_load,op_load,op_load,op_load };
      STATE_CALC: cs = { n,     n,     n,   y,    op_next,op_next,op_next,op_next };
      STATE_SIGN: cs = { n,     y,     n,   n,    1'bx,   1'bx,   1'bx,   1'bx    };
    endcase
  end

  assign mulreq_rdy     = cs[7];
  assign mulresp_val    = cs[6];
  assign sign_en        = cs[5];
  assign result_en      = cs[4];
  assign cntr_mux_sel   = cs[3];
  assign a_mux_sel      = cs[2];
  assign b_mux_sel      = cs[1];
  assign result_mux_sel = cs[0];

  assign add_mux_sel    = b_lsb;

endmodule

`endif
