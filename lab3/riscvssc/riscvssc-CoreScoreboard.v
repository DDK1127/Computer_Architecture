//=========================================================================
// 7-Stage RISCV Scoreboard (Dual-Issue Superscalar)
//=========================================================================

`ifndef RISCV_CORE_SCOREBOARD_V
`define RISCV_CORE_SCOREBOARD_V

module riscv_CoreScoreboard
(
  input            clk,
  input            reset,

  input            inst_val_Dhl,

  input      [4:0] src00,
  input            src00_en,
  input      [4:0] src01,
  input            src01_en,
  input      [4:0] src10,
  input            src10_en,
  input      [4:0] src11,
  input            src11_en,

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

  input            is_load_A_X0hl,
  input            is_muldiv_A_X0hl,
  input            is_muldiv_A_X1hl,
  input            is_muldiv_A_X2hl,

  input            stall_X0hl,
  input            stall_X1hl,
  input            stall_X2hl,
  input            stall_X3hl,

  output           stall_0_hazard,
  output           stall_1_hazard,

  output reg [3:0] src00_byp_mux_sel,
  output reg [3:0] src01_byp_mux_sel,
  output reg [3:0] src10_byp_mux_sel,
  output reg [3:0] src11_byp_mux_sel
);

  //----------------------------------------------------------------------
  // Bypass encoding helpers
  //----------------------------------------------------------------------

  localparam [3:0] byp_rdat = 4'd0;
  localparam [3:0] byp_AX0  = 4'd1;
  localparam [3:0] byp_AX1  = 4'd2;
  localparam [3:0] byp_AX2  = 4'd3;
  localparam [3:0] byp_AX3  = 4'd4;
  localparam [3:0] byp_AW   = 4'd5;
  localparam [3:0] byp_BX0  = 4'd6;
  localparam [3:0] byp_BX1  = 4'd7;
  localparam [3:0] byp_BX2  = 4'd8;
  localparam [3:0] byp_BX3  = 4'd9;
  localparam [3:0] byp_BW   = 4'd10;

  function [3:0] select_bypass;
    input match_AX0;
    input match_BX0;
    input match_AX1;
    input match_BX1;
    input match_AX2;
    input match_BX2;
    input match_AX3;
    input match_BX3;
    input match_AW;
    input match_BW;
    begin
      if      ( match_AX0 ) select_bypass = byp_AX0;
      else if ( match_BX0 ) select_bypass = byp_BX0;
      else if ( match_AX1 ) select_bypass = byp_AX1;
      else if ( match_BX1 ) select_bypass = byp_BX1;
      else if ( match_AX2 ) select_bypass = byp_AX2;
      else if ( match_BX2 ) select_bypass = byp_BX2;
      else if ( match_AX3 ) select_bypass = byp_AX3;
      else if ( match_BX3 ) select_bypass = byp_BX3;
      else if ( match_AW  ) select_bypass = byp_AW;
      else if ( match_BW  ) select_bypass = byp_BW;
      else                 select_bypass = byp_rdat;
    end
  endfunction

  //----------------------------------------------------------------------
  // Helper notes
  //
  // This scoreboard is purely combinational. It does two jobs:
  // 1. choose the best bypass source for each decode operand
  // 2. flag operands that still depend on a load or mul/div result that
  //    is not yet available for bypass
  //
  // The pending-table style scoreboard from the handout would also work,
  // but for this lab the in-flight stage metadata is already enough to
  // infer readiness directly.
  //----------------------------------------------------------------------

  //----------------------------------------------------------------------
  // Source 00
  //----------------------------------------------------------------------

  wire src00_match_AX0 = src00_en && instA_val_X0hl && rfA_wen_X0hl
                      && ( src00 == rfA_waddr_X0hl ) && ( rfA_waddr_X0hl != 5'd0 );
  wire src00_match_AX1 = src00_en && instA_val_X1hl && rfA_wen_X1hl
                      && ( src00 == rfA_waddr_X1hl ) && ( rfA_waddr_X1hl != 5'd0 );
  wire src00_match_AX2 = src00_en && instA_val_X2hl && rfA_wen_X2hl
                      && ( src00 == rfA_waddr_X2hl ) && ( rfA_waddr_X2hl != 5'd0 );
  wire src00_match_AX3 = src00_en && instA_val_X3hl && rfA_wen_X3hl
                      && ( src00 == rfA_waddr_X3hl ) && ( rfA_waddr_X3hl != 5'd0 );
  wire src00_match_AW  = src00_en && instA_val_Whl  && rfA_wen_Whl
                      && ( src00 == rfA_waddr_Whl )  && ( rfA_waddr_Whl != 5'd0 );

  wire src00_match_BX0 = src00_en && instB_val_X0hl && rfB_wen_X0hl
                      && ( src00 == rfB_waddr_X0hl ) && ( rfB_waddr_X0hl != 5'd0 );
  wire src00_match_BX1 = src00_en && instB_val_X1hl && rfB_wen_X1hl
                      && ( src00 == rfB_waddr_X1hl ) && ( rfB_waddr_X1hl != 5'd0 );
  wire src00_match_BX2 = src00_en && instB_val_X2hl && rfB_wen_X2hl
                      && ( src00 == rfB_waddr_X2hl ) && ( rfB_waddr_X2hl != 5'd0 );
  wire src00_match_BX3 = src00_en && instB_val_X3hl && rfB_wen_X3hl
                      && ( src00 == rfB_waddr_X3hl ) && ( rfB_waddr_X3hl != 5'd0 );
  wire src00_match_BW  = src00_en && instB_val_Whl  && rfB_wen_Whl
                      && ( src00 == rfB_waddr_Whl )  && ( rfB_waddr_Whl != 5'd0 );

  wire src00_unresolved = ( src00_match_AX0 && ( is_load_A_X0hl || is_muldiv_A_X0hl ) )
                       || ( src00_match_AX1 &&   is_muldiv_A_X1hl )
                       || ( src00_match_AX2 &&   is_muldiv_A_X2hl );

  //----------------------------------------------------------------------
  // Source 01
  //----------------------------------------------------------------------

  wire src01_match_AX0 = src01_en && instA_val_X0hl && rfA_wen_X0hl
                      && ( src01 == rfA_waddr_X0hl ) && ( rfA_waddr_X0hl != 5'd0 );
  wire src01_match_AX1 = src01_en && instA_val_X1hl && rfA_wen_X1hl
                      && ( src01 == rfA_waddr_X1hl ) && ( rfA_waddr_X1hl != 5'd0 );
  wire src01_match_AX2 = src01_en && instA_val_X2hl && rfA_wen_X2hl
                      && ( src01 == rfA_waddr_X2hl ) && ( rfA_waddr_X2hl != 5'd0 );
  wire src01_match_AX3 = src01_en && instA_val_X3hl && rfA_wen_X3hl
                      && ( src01 == rfA_waddr_X3hl ) && ( rfA_waddr_X3hl != 5'd0 );
  wire src01_match_AW  = src01_en && instA_val_Whl  && rfA_wen_Whl
                      && ( src01 == rfA_waddr_Whl )  && ( rfA_waddr_Whl != 5'd0 );

  wire src01_match_BX0 = src01_en && instB_val_X0hl && rfB_wen_X0hl
                      && ( src01 == rfB_waddr_X0hl ) && ( rfB_waddr_X0hl != 5'd0 );
  wire src01_match_BX1 = src01_en && instB_val_X1hl && rfB_wen_X1hl
                      && ( src01 == rfB_waddr_X1hl ) && ( rfB_waddr_X1hl != 5'd0 );
  wire src01_match_BX2 = src01_en && instB_val_X2hl && rfB_wen_X2hl
                      && ( src01 == rfB_waddr_X2hl ) && ( rfB_waddr_X2hl != 5'd0 );
  wire src01_match_BX3 = src01_en && instB_val_X3hl && rfB_wen_X3hl
                      && ( src01 == rfB_waddr_X3hl ) && ( rfB_waddr_X3hl != 5'd0 );
  wire src01_match_BW  = src01_en && instB_val_Whl  && rfB_wen_Whl
                      && ( src01 == rfB_waddr_Whl )  && ( rfB_waddr_Whl != 5'd0 );

  wire src01_unresolved = ( src01_match_AX0 && ( is_load_A_X0hl || is_muldiv_A_X0hl ) )
                       || ( src01_match_AX1 &&   is_muldiv_A_X1hl )
                       || ( src01_match_AX2 &&   is_muldiv_A_X2hl );

  //----------------------------------------------------------------------
  // Source 10
  //----------------------------------------------------------------------

  wire src10_match_AX0 = src10_en && instA_val_X0hl && rfA_wen_X0hl
                      && ( src10 == rfA_waddr_X0hl ) && ( rfA_waddr_X0hl != 5'd0 );
  wire src10_match_AX1 = src10_en && instA_val_X1hl && rfA_wen_X1hl
                      && ( src10 == rfA_waddr_X1hl ) && ( rfA_waddr_X1hl != 5'd0 );
  wire src10_match_AX2 = src10_en && instA_val_X2hl && rfA_wen_X2hl
                      && ( src10 == rfA_waddr_X2hl ) && ( rfA_waddr_X2hl != 5'd0 );
  wire src10_match_AX3 = src10_en && instA_val_X3hl && rfA_wen_X3hl
                      && ( src10 == rfA_waddr_X3hl ) && ( rfA_waddr_X3hl != 5'd0 );
  wire src10_match_AW  = src10_en && instA_val_Whl  && rfA_wen_Whl
                      && ( src10 == rfA_waddr_Whl )  && ( rfA_waddr_Whl != 5'd0 );

  wire src10_match_BX0 = src10_en && instB_val_X0hl && rfB_wen_X0hl
                      && ( src10 == rfB_waddr_X0hl ) && ( rfB_waddr_X0hl != 5'd0 );
  wire src10_match_BX1 = src10_en && instB_val_X1hl && rfB_wen_X1hl
                      && ( src10 == rfB_waddr_X1hl ) && ( rfB_waddr_X1hl != 5'd0 );
  wire src10_match_BX2 = src10_en && instB_val_X2hl && rfB_wen_X2hl
                      && ( src10 == rfB_waddr_X2hl ) && ( rfB_waddr_X2hl != 5'd0 );
  wire src10_match_BX3 = src10_en && instB_val_X3hl && rfB_wen_X3hl
                      && ( src10 == rfB_waddr_X3hl ) && ( rfB_waddr_X3hl != 5'd0 );
  wire src10_match_BW  = src10_en && instB_val_Whl  && rfB_wen_Whl
                      && ( src10 == rfB_waddr_Whl )  && ( rfB_waddr_Whl != 5'd0 );

  wire src10_unresolved = ( src10_match_AX0 && ( is_load_A_X0hl || is_muldiv_A_X0hl ) )
                       || ( src10_match_AX1 &&   is_muldiv_A_X1hl )
                       || ( src10_match_AX2 &&   is_muldiv_A_X2hl );

  //----------------------------------------------------------------------
  // Source 11
  //----------------------------------------------------------------------

  wire src11_match_AX0 = src11_en && instA_val_X0hl && rfA_wen_X0hl
                      && ( src11 == rfA_waddr_X0hl ) && ( rfA_waddr_X0hl != 5'd0 );
  wire src11_match_AX1 = src11_en && instA_val_X1hl && rfA_wen_X1hl
                      && ( src11 == rfA_waddr_X1hl ) && ( rfA_waddr_X1hl != 5'd0 );
  wire src11_match_AX2 = src11_en && instA_val_X2hl && rfA_wen_X2hl
                      && ( src11 == rfA_waddr_X2hl ) && ( rfA_waddr_X2hl != 5'd0 );
  wire src11_match_AX3 = src11_en && instA_val_X3hl && rfA_wen_X3hl
                      && ( src11 == rfA_waddr_X3hl ) && ( rfA_waddr_X3hl != 5'd0 );
  wire src11_match_AW  = src11_en && instA_val_Whl  && rfA_wen_Whl
                      && ( src11 == rfA_waddr_Whl )  && ( rfA_waddr_Whl != 5'd0 );

  wire src11_match_BX0 = src11_en && instB_val_X0hl && rfB_wen_X0hl
                      && ( src11 == rfB_waddr_X0hl ) && ( rfB_waddr_X0hl != 5'd0 );
  wire src11_match_BX1 = src11_en && instB_val_X1hl && rfB_wen_X1hl
                      && ( src11 == rfB_waddr_X1hl ) && ( rfB_waddr_X1hl != 5'd0 );
  wire src11_match_BX2 = src11_en && instB_val_X2hl && rfB_wen_X2hl
                      && ( src11 == rfB_waddr_X2hl ) && ( rfB_waddr_X2hl != 5'd0 );
  wire src11_match_BX3 = src11_en && instB_val_X3hl && rfB_wen_X3hl
                      && ( src11 == rfB_waddr_X3hl ) && ( rfB_waddr_X3hl != 5'd0 );
  wire src11_match_BW  = src11_en && instB_val_Whl  && rfB_wen_Whl
                      && ( src11 == rfB_waddr_Whl )  && ( rfB_waddr_Whl != 5'd0 );

  wire src11_unresolved = ( src11_match_AX0 && ( is_load_A_X0hl || is_muldiv_A_X0hl ) )
                       || ( src11_match_AX1 &&   is_muldiv_A_X1hl )
                       || ( src11_match_AX2 &&   is_muldiv_A_X2hl );

  //----------------------------------------------------------------------
  // Bypass select encoding
  //----------------------------------------------------------------------

  // Bypass priority is ordered by recency, not by pipeline name:
  //   X0 -> X1 -> X2 -> X3 -> W
  // and within the same stage we prefer the newer B-side result after the
  // corresponding A-side result has been checked for that stage. This keeps
  // decode from accidentally using an older writeback value when a newer
  // in-flight producer already exists in B.

  always @(*) begin
    src00_byp_mux_sel = select_bypass(
      src00_match_AX0, src00_match_BX0,
      src00_match_AX1, src00_match_BX1,
      src00_match_AX2, src00_match_BX2,
      src00_match_AX3, src00_match_BX3,
      src00_match_AW,  src00_match_BW
    );
  end

  always @(*) begin
    src01_byp_mux_sel = select_bypass(
      src01_match_AX0, src01_match_BX0,
      src01_match_AX1, src01_match_BX1,
      src01_match_AX2, src01_match_BX2,
      src01_match_AX3, src01_match_BX3,
      src01_match_AW,  src01_match_BW
    );
  end

  always @(*) begin
    src10_byp_mux_sel = select_bypass(
      src10_match_AX0, src10_match_BX0,
      src10_match_AX1, src10_match_BX1,
      src10_match_AX2, src10_match_BX2,
      src10_match_AX3, src10_match_BX3,
      src10_match_AW,  src10_match_BW
    );
  end

  always @(*) begin
    src11_byp_mux_sel = select_bypass(
      src11_match_AX0, src11_match_BX0,
      src11_match_AX1, src11_match_BX1,
      src11_match_AX2, src11_match_BX2,
      src11_match_AX3, src11_match_BX3,
      src11_match_AW,  src11_match_BW
    );
  end

  //----------------------------------------------------------------------
  // Hazard outputs
  //----------------------------------------------------------------------

  assign stall_0_hazard = src00_unresolved || src01_unresolved;
  assign stall_1_hazard = src10_unresolved || src11_unresolved;

endmodule

`endif
