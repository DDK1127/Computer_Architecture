//====================================================================================
// Victim Cache Design (2-entry fully associative) [FIXED]
//====================================================================================

`ifndef RISCV_VICTIM_CACHE_V
`define RISCV_VICTIM_CACHE_V

`include "riscvbc-CacheMsg.v"
`include "vc-RAMs.v"

module riscv_VictimCache 
(
    input clk,
    input reset,
    
    // Interface with main cache
    input                       vc_en,          
    input                       vc_write,       
    input  [31:0]               vc_addr,        // Full address
    input  [`D_BLK_SIZE-1:0]    vc_wdata,       
    input  [22:0]               vc_wtag,        // Tag from Main Cache {Valid, Dirty, Tag[20:0]}
    
    output                      vc_hit,         
    output                      vc_way,         
    output [`D_BLK_SIZE-1:0]    vc_rdata,       
    output [22:0]               vc_rtag         
);

    //------------------------------------------------------------------------
    // Parameter & Address Parse
    //------------------------------------------------------------------------
    // Assuming 4KB Cache, 2-way, 64B block => 32 Sets => 5-bit Index
    // Addr: Tag[31:11] | Index[10:6] | Offset[5:0]
    
    wire [20:0] req_tag = vc_addr[31:11];
    wire [4:0]  req_idx = vc_addr[10:6];   // [FIX] Need to extract Index

    //------------------------------------------------------------------------
    // RAM outputs
    //------------------------------------------------------------------------
    // We need to widen the internal storage to hold the Index.
    // vc_wtag is 23 bits: {Valid(1), Dirty(1), Tag(21)}
    // Stored Tag needs to be: {Valid(1), Dirty(1), Tag(21), Index(5)} = 28 bits

    wire [`D_BLK_SIZE-1:0] vc_data0, vc_data1;
    wire [27:0]            vc_tag_entry0, vc_tag_entry1; // [FIX] Widened to 28 bits

    // Unpack stored entries
    wire        valid0      = vc_tag_entry0[27];
    wire        dirty0      = vc_tag_entry0[26];
    wire [20:0] stored_tag0 = vc_tag_entry0[25:5];
    wire [4:0]  stored_idx0 = vc_tag_entry0[4:0];    // [FIX] Stored Index

    wire        valid1      = vc_tag_entry1[27];
    wire        dirty1      = vc_tag_entry1[26];
    wire [20:0] stored_tag1 = vc_tag_entry1[25:5];
    wire [4:0]  stored_idx1 = vc_tag_entry1[4:0];

    // [FIX] Write Data Construction: Append current Index to the tag info
    wire [27:0] vc_wtag_extended = { vc_wtag, req_idx };

    //------------------------------------------------------------------------
    // Hit Detection
    //------------------------------------------------------------------------

    // [FIX] Match logic must check BOTH Tag AND Index
    wire match0 = (req_tag == stored_tag0) && (req_idx == stored_idx0);
    wire match1 = (req_tag == stored_tag1) && (req_idx == stored_idx1);

    wire hit0 = valid0 && match0;
    wire hit1 = valid1 && match1;

    // [FIX] Gate hit with enable signal
    assign vc_hit = vc_en && (hit0 || hit1); 
    assign vc_way = hit1;

    // Output hit data
    assign vc_rdata = hit1 ? vc_data1 : vc_data0;
    
    // Output tag to Main Cache (Must match Main Cache format: 23 bits)
    // We reconstruct {Valid, Dirty, Tag} from our extended entry
    assign vc_rtag  = hit1 ? vc_tag_entry1[27:5] : vc_tag_entry0[27:5];

    //------------------------------------------------------------------------
    // Replacement Policy (FIFO)
    //------------------------------------------------------------------------

    reg fifo_ptr;

    always @(posedge clk) begin
        if (reset) begin
            fifo_ptr <= 1'b0;
        end
        else if (vc_write && vc_en) begin
            fifo_ptr <= ~fifo_ptr;
        end
    end

    wire wen0 = vc_write && vc_en && (fifo_ptr == 1'b0);
    wire wen1 = vc_write && vc_en && (fifo_ptr == 1'b1);

    //------------------------------------------------------------------------
    // Victim Cache RAMs
    //------------------------------------------------------------------------

    // Way 0 Data
    vc_RAM_rst_1w1r_pf #(
        .DATA_SZ     (`D_BLK_SIZE),
        .ENTRIES     (1),
        .ADDR_SZ     (1),
        .RESET_VALUE (0)
    ) VC_data0 (
        .clk         (clk),
        .reset_p     (reset),
        .raddr       (1'b0),
        .rdata       (vc_data0),
        .wen_p       (wen0),
        .waddr_p     (1'b0),
        .wdata_p     (vc_wdata)
    ); 

    // Way 0 Tag [FIXED WIDTH]
    vc_RAM_rst_1w1r_pf #(
        .DATA_SZ     (28), // [FIX] 23 (Tag info) + 5 (Index)
        .ENTRIES     (1),
        .ADDR_SZ     (1),
        .RESET_VALUE (0)
    ) VC_tag0 (
        .clk         (clk),
        .reset_p     (reset),
        .raddr       (1'b0),
        .rdata       (vc_tag_entry0),
        .wen_p       (wen0),
        .waddr_p     (1'b0),
        .wdata_p     (vc_wtag_extended) // [FIX] Write extended tag
    );

    // Way 1 Data
    vc_RAM_rst_1w1r_pf #(
        .DATA_SZ     (`D_BLK_SIZE),
        .ENTRIES     (1),
        .ADDR_SZ     (1),
        .RESET_VALUE (0)
    ) VC_data1 (
        .clk         (clk),
        .reset_p     (reset),
        .raddr       (1'b0),
        .rdata       (vc_data1),
        .wen_p       (wen1),
        .waddr_p     (1'b0),
        .wdata_p     (vc_wdata)
    ); 

    // Way 1 Tag [FIXED WIDTH]
    vc_RAM_rst_1w1r_pf #(
        .DATA_SZ     (28), // [FIX] 23 (Tag info) + 5 (Index)
        .ENTRIES     (1),
        .ADDR_SZ     (1),
        .RESET_VALUE (0)
    ) VC_tag1 (
        .clk         (clk),
        .reset_p     (reset),
        .raddr       (1'b0),
        .rdata       (vc_tag_entry1),
        .wen_p       (wen1),
        .waddr_p     (1'b0),
        .wdata_p     (vc_wtag_extended) // [FIX] Write extended tag
    );

endmodule

`endif