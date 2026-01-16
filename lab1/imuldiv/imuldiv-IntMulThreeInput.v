//======================================================================== 
// Lab 1 - Three Input Iterative Mul Unit
//========================================================================

`ifndef RISCV_INT_MULDIV_THREEINPUT_V
`define RISCV_INT_MULDIV_THREEINPUT_V

`include "imuldiv-ThreeMulReqMsg.v"
`include "imuldiv-IntMulBooth.v"

module imuldiv_IntMulThreeInput (
  input         clk,
  input         reset,
  
  input   [2:0] muldivreq_msg_fn,
  input  [31:0] muldivreq_msg_a,
  input  [31:0] muldivreq_msg_b,
  input  [31:0] muldivreq_msg_c,
  input         muldivreq_val,
  output        muldivreq_rdy,
  
  output reg [95:0] muldivresp_msg_result,
  output reg        muldivresp_val,
  input             muldivresp_rdy
);

  // 狀態編碼
  localparam IDLE   = 3'd0;
  localparam STEP1  = 3'd1;
  localparam STEP2  = 3'd2;
  localparam STEP3  = 3'd3;
  localparam DONE   = 3'd4;

  reg [2:0] state, next_state;

  // 暫存 input
  reg [31:0] reg_a, reg_b, reg_c;

  // Booth multiplier I/O
  reg  [31:0] booth_a, booth_b;
  reg         booth_val;
  wire        booth_rdy;
  wire [63:0] booth_result;
  wire        booth_result_val;

  imuldiv_IntMulBooth booth_inst (
    .clk(clk),
    .reset(reset),
    .mulreq_msg_a(booth_a),
    .mulreq_msg_b(booth_b),
    .mulreq_val(booth_val),
    .mulreq_rdy(booth_rdy),
    .mulresp_msg_result(booth_result),
    .mulresp_val(booth_result_val),
    .mulresp_rdy(1'b1)   // always ready
  );

  // 暫存中間結果
  reg [63:0] prod_ab;
  reg [63:0] part_lo;
  reg [63:0] part_hi;
  
  // 檢測P_low的符號位，用於修正計算
  wire p_low_sign = prod_ab[31];

  // 輸入 ready 只在 IDLE
  assign muldivreq_rdy = (state == IDLE);

  // 狀態轉移
  always @(*) begin
    next_state = state;
    case (state)
      IDLE:   if (muldivreq_val && muldivreq_rdy) next_state = STEP1;
      STEP1:  if (booth_result_val) next_state = STEP2;
      STEP2:  if (booth_result_val) next_state = STEP3;
      STEP3:  if (booth_result_val) next_state = DONE;
      DONE:   if (muldivresp_val && muldivresp_rdy) next_state = IDLE;
    endcase
  end

  // 狀態暫存
  always @(posedge clk or posedge reset) begin
    if (reset) state <= IDLE;
    else       state <= next_state;
  end

  // 控制 Booth input
  always @(*) begin
    booth_a   = 32'b0;
    booth_b   = 32'b0;
    booth_val = 1'b0;
    case (state)
      STEP1: begin
        booth_a   = reg_a;
        booth_b   = reg_b;
        booth_val = 1'b1;
      end
      STEP2: begin
        booth_a   = {1'b0, prod_ab[30:0]}; // P_lo (會被當作有符號數，稍後修正)
        booth_b   = reg_c;
        booth_val = 1'b1;
      end
      STEP3: begin
        booth_a   = prod_ab[63:32]; // P_hi (正確的有符號數)
        booth_b   = reg_c;
        booth_val = 1'b1;
      end
    endcase
  end

  // 計算流程
  always @(posedge clk) begin
    if (reset) begin
      reg_a <= 0; reg_b <= 0; reg_c <= 0;
      prod_ab <= 0; part_lo <= 0; part_hi <= 0;
      muldivresp_msg_result <= 0;
      muldivresp_val <= 0;
    end
    else begin
      case (state)
        IDLE: if (muldivreq_val && muldivreq_rdy) begin
          reg_a <= muldivreq_msg_a;
          reg_b <= muldivreq_msg_b;
          reg_c <= muldivreq_msg_c;
          muldivresp_val <= 1'b0;
        end
        
        STEP1: if (booth_result_val) begin
          prod_ab <= booth_result;
        end
        
        // P_lo × C，結果存在part_lo
        STEP2: if (booth_result_val) begin
          part_lo <= booth_result;
        end
        
        // P_hi × C，結果存在part_hi  
        STEP3: if (booth_result_val) begin
          part_hi <= booth_result;
        end
        
        DONE: begin
          // art_hi << 32 + part_lo
          // if (p_low_sign = 1) => reg_c << 32
          muldivresp_msg_result <= 
            {part_hi[63:0], 32'b0} +  // part_hi << 32
            part_lo[63:0] +         // part_lo
            (p_low_sign ? {{33'b0, reg_c, 31'b0}} : 96'b0); 
            
            // bcs part_lo[31](p_low_sign) set 0 to calculate,
            // so if part_lo[31] == 1, we need add back.

          
          muldivresp_val <= 1'b1;
          
          if (muldivresp_val && muldivresp_rdy)
            muldivresp_val <= 1'b0; // handshake consumed
        end
      endcase
    end
  end

endmodule

`endif