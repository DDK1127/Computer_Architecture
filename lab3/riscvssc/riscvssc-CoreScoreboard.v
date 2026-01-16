//=========================================================================
// 7-Stage RISCV Scoreboard (Dual-Issue Superscalar)
//=========================================================================

`ifndef RISCV_CORE_SCOREBOARD_V
`define RISCV_CORE_SCOREBOARD_V

module riscv_CoreScoreboard
(
  input            clk,
  input            reset,

  // Decode stage source regs --------------------------------------------
  input            inst_val_Dhl,
  // src0* = instruction 0, * -> pipeline A(0) or B(1)
  input      [4:0] src00,
  input            src00_en,
  input      [4:0] src01,
  input            src01_en,
  // src1* = instruction 1, * -> pipeline A(0) or B(1)
  input      [4:0] src10,
  input            src10_en,
  input      [4:0] src11,
  input            src11_en,

  // Decode destination regs ---------------------------------------------
  input      [4:0] dstA,
  input            dstA_en,
  input            stall_A_Dhl,
  input            is_muldiv_A,
  input            is_load_A,

  input      [4:0] dstB,
  input            dstB_en,
  input            stall_B_Dhl,
  input            is_muldiv_B,
  input            is_load_B,

  // Pipeline A stage valid + write info ---------------------------------
  input            instA_val_X0hl,
  input            instA_val_X1hl,
  input            instA_val_X2hl,
  input            instA_val_X3hl,
  input            instA_val_Whl,
  input            rfA_wen_X0hl,
  input            rfA_wen_X1hl,
  input            rfA_wen_X2hl,
  input            rfA_wen_X3hl,
  input            rfA_wen_Whl,
  input      [4:0] rfA_waddr_X0hl,
  input      [4:0] rfA_waddr_X1hl,
  input      [4:0] rfA_waddr_X2hl,
  input      [4:0] rfA_waddr_X3hl,
  input      [4:0] rfA_waddr_Whl,

  // Pipeline B stage valid + write info ---------------------------------
  input            instB_val_X0hl,
  input            instB_val_X1hl,
  input            instB_val_X2hl,
  input            instB_val_X3hl,
  input            instB_val_Whl,
  input            rfB_wen_X0hl,
  input            rfB_wen_X1hl,
  input            rfB_wen_X2hl,
  input            rfB_wen_X3hl,
  input            rfB_wen_Whl,
  input      [4:0] rfB_waddr_X0hl,
  input      [4:0] rfB_waddr_X1hl,
  input      [4:0] rfB_waddr_X2hl,
  input      [4:0] rfB_waddr_X3hl,
  input      [4:0] rfB_waddr_Whl,

  // Global stall info ----------------------------------------------------
  input            stall_X0hl,
  input            stall_X1hl,
  input            stall_X2hl,
  input            stall_X3hl,

  // Outputs --------------------------------------------------------------
  output           stall_0_hazard,
  output           stall_1_hazard,

  output reg [3:0] src00_byp_mux_sel,
  output reg [3:0] src01_byp_mux_sel,
  output reg [3:0] src10_byp_mux_sel,
  output reg [3:0] src11_byp_mux_sel
);

  //----------------------------------------------------------------------
  // Register pending table
  //----------------------------------------------------------------------

  reg [1:0] reg_pending [0:31]; // bit 0. =pipeA, bit 1 =pipeB
  integer i;

  always @(posedge clk) begin
    if (reset) begin
      for (i = 0; i < 32; i = i + 1)
        reg_pending[i] <= 2'b00;
    end
    else begin
      // Writeback clear, cancel peding
      if (instA_val_Whl && rfA_wen_Whl && (rfA_waddr_Whl != 5'd0))
        reg_pending[rfA_waddr_Whl][0] <= 1'b0;

      if (instB_val_Whl && rfB_wen_Whl && (rfB_waddr_Whl != 5'd0))
        reg_pending[rfB_waddr_Whl][1] <= 1'b0;

      // New decode issue, pending new register
      if (inst_val_Dhl && dstA_en && !stall_A_Dhl && (dstA != 5'd0) && !stall_X0hl)
        reg_pending[dstA][0] <= 1'b1;

      if (inst_val_Dhl && dstB_en && !stall_B_Dhl && (dstB != 5'd0) && !stall_X0hl)
        reg_pending[dstB][1] <= 1'b1;
    end
  end

  //----------------------------------------------------------------------
  // RAW hazard detection
  //----------------------------------------------------------------------

  wire hazard_src00 = src00_en && (src00 != 5'd0) && (reg_pending[src00] != 2'b00);
  wire hazard_src01 = src01_en && (src01 != 5'd0) && (reg_pending[src01] != 2'b00);
  wire hazard_src10 = src10_en && (src10 != 5'd0) && (reg_pending[src10] != 2'b00);
  wire hazard_src11 = src11_en && (src11 != 5'd0) && (reg_pending[src11] != 2'b00);

  //----------------------------------------------------------------------
  // Bypass detection
  //----------------------------------------------------------------------

  // Example: src00 vs every stage
  wire src00_AX0_byp = src00_en && instA_val_X0hl && rfA_wen_X0hl &&
                       (src00 == rfA_waddr_X0hl) && (rfA_waddr_X0hl != 5'd0);
  wire src00_AX1_byp = src00_en && instA_val_X1hl && rfA_wen_X1hl &&
                       (src00 == rfA_waddr_X1hl) && (rfA_waddr_X1hl != 5'd0);
  wire src00_AX2_byp = src00_en && instA_val_X2hl && rfA_wen_X2hl &&
                       (src00 == rfA_waddr_X2hl) && (rfA_waddr_X2hl != 5'd0);
  wire src00_AX3_byp = src00_en && instA_val_X3hl && rfA_wen_X3hl &&
                       (src00 == rfA_waddr_X3hl) && (rfA_waddr_X3hl != 5'd0);
  wire src00_AW_byp  = src00_en && instA_val_Whl  && rfA_wen_Whl  &&
                       (src00 == rfA_waddr_Whl)  && (rfA_waddr_Whl != 5'd0);

  wire src00_BX0_byp = src00_en && instB_val_X0hl && rfB_wen_X0hl &&
                       (src00 == rfB_waddr_X0hl) && (rfB_waddr_X0hl != 5'd0);
  wire src00_BX1_byp = src00_en && instB_val_X1hl && rfB_wen_X1hl &&
                       (src00 == rfB_waddr_X1hl) && (rfB_waddr_X1hl != 5'd0);
  wire src00_BX2_byp = src00_en && instB_val_X2hl && rfB_wen_X2hl &&
                       (src00 == rfB_waddr_X2hl) && (rfB_waddr_X2hl != 5'd0);
  wire src00_BX3_byp = src00_en && instB_val_X3hl && rfB_wen_X3hl &&
                       (src00 == rfB_waddr_X3hl) && (rfB_waddr_X3hl != 5'd0);
  wire src00_BW_byp  = src00_en && instB_val_Whl  && rfB_wen_Whl  &&
                       (src00 == rfB_waddr_Whl)  && (rfB_waddr_Whl != 5'd0);

  wire src01_AX0_byp = src01_en && instA_val_X0hl && rfA_wen_X0hl &&
                       (src01 == rfA_waddr_X0hl) && (rfA_waddr_X0hl != 5'd0);
  wire src01_AX1_byp = src01_en && instA_val_X1hl && rfA_wen_X1hl &&
                       (src01 == rfA_waddr_X1hl) && (rfA_waddr_X1hl != 5'd0);
  wire src01_AX2_byp = src01_en && instA_val_X2hl && rfA_wen_X2hl &&
                       (src01 == rfA_waddr_X2hl) && (rfA_waddr_X2hl != 5'd0);
  wire src01_AX3_byp = src01_en && instA_val_X3hl && rfA_wen_X3hl &&
                       (src01 == rfA_waddr_X3hl) && (rfA_waddr_X3hl != 5'd0);
  wire src01_AW_byp  = src01_en && instA_val_Whl  && rfA_wen_Whl  &&
                       (src01 == rfA_waddr_Whl)  && (rfA_waddr_Whl != 5'd0);

  wire src01_BX0_byp = src01_en && instB_val_X0hl && rfB_wen_X0hl &&
                       (src01 == rfB_waddr_X0hl) && (rfB_waddr_X0hl != 5'd0);
  wire src01_BX1_byp = src01_en && instB_val_X1hl && rfB_wen_X1hl &&
                       (src01 == rfB_waddr_X1hl) && (rfB_waddr_X1hl != 5'd0);
  wire src01_BX2_byp = src01_en && instB_val_X2hl && rfB_wen_X2hl &&
                       (src01 == rfB_waddr_X2hl) && (rfB_waddr_X2hl != 5'd0);
  wire src01_BX3_byp = src01_en && instB_val_X3hl && rfB_wen_X3hl &&
                       (src01 == rfB_waddr_X3hl) && (rfB_waddr_X3hl != 5'd0);
  wire src01_BW_byp  = src01_en && instB_val_Whl  && rfB_wen_Whl  &&
                       (src01 == rfB_waddr_Whl)  && (rfB_waddr_Whl != 5'd0);

  wire src10_AX0_byp = src10_en && instA_val_X0hl && rfA_wen_X0hl &&
                       (src10 == rfA_waddr_X0hl) && (rfA_waddr_X0hl != 5'd0);
  wire src10_AX1_byp = src10_en && instA_val_X1hl && rfA_wen_X1hl &&
                       (src10 == rfA_waddr_X1hl) && (rfA_waddr_X1hl != 5'd0);
  wire src10_AX2_byp = src10_en && instA_val_X2hl && rfA_wen_X2hl &&
                       (src10 == rfA_waddr_X2hl) && (rfA_waddr_X2hl != 5'd0);
  wire src10_AX3_byp = src10_en && instA_val_X3hl && rfA_wen_X3hl &&
                       (src10 == rfA_waddr_X3hl) && (rfA_waddr_X3hl != 5'd0);
  wire src10_AW_byp  = src10_en && instA_val_Whl  && rfA_wen_Whl  &&
                       (src10 == rfA_waddr_Whl)  && (rfA_waddr_Whl != 5'd0);

  wire src10_BX0_byp = src10_en && instB_val_X0hl && rfB_wen_X0hl &&
                       (src10 == rfB_waddr_X0hl) && (rfB_waddr_X0hl != 5'd0);
  wire src10_BX1_byp = src10_en && instB_val_X1hl && rfB_wen_X1hl &&
                       (src10 == rfB_waddr_X1hl) && (rfB_waddr_X1hl != 5'd0);
  wire src10_BX2_byp = src10_en && instB_val_X2hl && rfB_wen_X2hl &&
                       (src10 == rfB_waddr_X2hl) && (rfB_waddr_X2hl != 5'd0);
  wire src10_BX3_byp = src10_en && instB_val_X3hl && rfB_wen_X3hl &&
                       (src10 == rfB_waddr_X3hl) && (rfB_waddr_X3hl != 5'd0);
  wire src10_BW_byp  = src10_en && instB_val_Whl  && rfB_wen_Whl  &&
                       (src10 == rfB_waddr_Whl)  && (rfB_waddr_Whl != 5'd0);

  wire src11_AX0_byp = src11_en && instA_val_X0hl && rfA_wen_X0hl &&
                       (src11 == rfA_waddr_X0hl) && (rfA_waddr_X0hl != 5'd0);
  wire src11_AX1_byp = src11_en && instA_val_X1hl && rfA_wen_X1hl &&
                       (src11 == rfA_waddr_X1hl) && (rfA_waddr_X1hl != 5'd0);
  wire src11_AX2_byp = src11_en && instA_val_X2hl && rfA_wen_X2hl &&
                       (src11 == rfA_waddr_X2hl) && (rfA_waddr_X2hl != 5'd0);
  wire src11_AX3_byp = src11_en && instA_val_X3hl && rfA_wen_X3hl &&
                       (src11 == rfA_waddr_X3hl) && (rfA_waddr_X3hl != 5'd0);
  wire src11_AW_byp  = src11_en && instA_val_Whl  && rfA_wen_Whl  &&
                       (src11 == rfA_waddr_Whl)  && (rfA_waddr_Whl != 5'd0);

  wire src11_BX0_byp = src11_en && instB_val_X0hl && rfB_wen_X0hl &&
                       (src11 == rfB_waddr_X0hl) && (rfB_waddr_X0hl != 5'd0);
  wire src11_BX1_byp = src11_en && instB_val_X1hl && rfB_wen_X1hl &&
                       (src11 == rfB_waddr_X1hl) && (rfB_waddr_X1hl != 5'd0);
  wire src11_BX2_byp = src11_en && instB_val_X2hl && rfB_wen_X2hl &&
                       (src11 == rfB_waddr_X2hl) && (rfB_waddr_X2hl != 5'd0);
  wire src11_BX3_byp = src11_en && instB_val_X3hl && rfB_wen_X3hl &&
                       (src11 == rfB_waddr_X3hl) && (rfB_waddr_X3hl != 5'd0);
  wire src11_BW_byp  = src11_en && instB_val_Whl  && rfB_wen_Whl  &&
                       (src11 == rfB_waddr_Whl)  && (rfB_waddr_Whl != 5'd0);

  // or generate block 

  //----------------------------------------------------------------------
  // Bypass mux select encoding
  //----------------------------------------------------------------------

  always @(*) begin
    src00_byp_mux_sel = 4'd0;
    if(src00_AX0_byp)       src00_byp_mux_sel = 4'd1;
    else if (src00_AX1_byp) src00_byp_mux_sel = 4'd2;
    else if (src00_AX2_byp) src00_byp_mux_sel = 4'd3;
    else if (src00_AX3_byp) src00_byp_mux_sel = 4'd4;
    else if (src00_AW_byp)  src00_byp_mux_sel = 4'd5;
    else if (src00_BX0_byp) src00_byp_mux_sel = 4'd6;
    else if (src00_BX1_byp) src00_byp_mux_sel = 4'd7;
    else if (src00_BX2_byp) src00_byp_mux_sel = 4'd8;
    else if (src00_BX3_byp) src00_byp_mux_sel = 4'd9;
    else if (src00_BW_byp)  src00_byp_mux_sel = 4'd10;
  end

  // always @(*) src01_byp_mux_sel = 4'd0;
  // always @(*) src10_byp_mux_sel = 4'd0;
  // always @(*) src11_byp_mux_sel = 4'd0;

  //----------------------------------------------------------------------
  // Stall logic
  // - If hazard detected but not resolvable via bypass, assert stall.
  //----------------------------------------------------------------------

  assign stall_0_hazard = (hazard_src00 || hazard_src01);
  assign stall_1_hazard = (hazard_src10 || hazard_src11);

endmodule

`endif
