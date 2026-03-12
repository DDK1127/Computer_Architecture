//=========================================================================
// Victim Cache Design (2-entry fully associative)
//=========================================================================

`ifndef RISCV_VICTIM_CACHE_V
`define RISCV_VICTIM_CACHE_V

`include "riscvbc-CacheMsg.v"
`include "vc-RAMs.v"

module riscv_VictimCache
(
    input                    clk,
    input                    reset,

    input      [31:0]        vc_addr,

    output                   vc_hit,
    output                   vc_hit_way,
    output [`BLK_SIZE-1:0]   vc_hit_data,
    output [22:0]            vc_hit_tag,

    output                   vc_alloc_way,
    output [`BLK_SIZE-1:0]   vc_alloc_data,
    output [22:0]            vc_alloc_tag,
    output [31:0]            vc_alloc_addr,
    output                   vc_alloc_valid,
    output                   vc_alloc_dirty,

    input                    vc_write_en,
    input                    vc_write_way,
    input      [31:0]        vc_write_addr,
    input      [`BLK_SIZE-1:0] vc_write_data,
    input      [22:0]        vc_write_tag
);

    localparam VC_TAG_SZ = 28;

    wire [20:0] req_tag = vc_addr[31:11];
    wire [4:0]  req_idx = vc_addr[10:6];

    wire [`BLK_SIZE-1:0] data0;
    wire [`BLK_SIZE-1:0] data1;
    wire [VC_TAG_SZ-1:0] tag_entry0;
    wire [VC_TAG_SZ-1:0] tag_entry1;

    wire        valid0      = tag_entry0[27];
    wire        dirty0      = tag_entry0[26];
    wire [20:0] stored_tag0 = tag_entry0[25:5];
    wire [4:0]  stored_idx0 = tag_entry0[4:0];

    wire        valid1      = tag_entry1[27];
    wire        dirty1      = tag_entry1[26];
    wire [20:0] stored_tag1 = tag_entry1[25:5];
    wire [4:0]  stored_idx1 = tag_entry1[4:0];

    wire hit0 = valid0 && (req_tag == stored_tag0) && (req_idx == stored_idx0);
    wire hit1 = valid1 && (req_tag == stored_tag1) && (req_idx == stored_idx1);

    assign vc_hit      = hit0 || hit1;
    assign vc_hit_way  = hit1;
    assign vc_hit_data = hit1 ? data1 : data0;
    assign vc_hit_tag  = hit1 ? tag_entry1[27:5] : tag_entry0[27:5];

    reg fifo_ptr;

    always @(posedge clk) begin
        if (reset)
            fifo_ptr <= 1'b0;
        else if (vc_write_en && vc_write_tag[22])
            fifo_ptr <= ~fifo_ptr;
    end

    assign vc_alloc_way   = !valid0 ? `WAY0 :
                            !valid1 ? `WAY1 :
                                      fifo_ptr;
    assign vc_alloc_data  = vc_alloc_way ? data1 : data0;
    assign vc_alloc_tag   = vc_alloc_way ? tag_entry1[27:5] : tag_entry0[27:5];
    assign vc_alloc_valid = vc_alloc_tag[22];
    assign vc_alloc_dirty = vc_alloc_tag[21];
    assign vc_alloc_addr  = vc_alloc_way
                          ? { stored_tag1, stored_idx1, 6'b0 }
                          : { stored_tag0, stored_idx0, 6'b0 };

    wire [VC_TAG_SZ-1:0] write_tag_entry =
        { vc_write_tag, vc_write_addr[10:6] };

    wire wen0 = vc_write_en && (vc_write_way == `WAY0);
    wire wen1 = vc_write_en && (vc_write_way == `WAY1);

    vc_RAM_rst_1w1r_pf #(
        .DATA_SZ     (`BLK_SIZE),
        .ENTRIES     (1),
        .ADDR_SZ     (1),
        .RESET_VALUE (0)
    ) vc_data0 (
        .clk         (clk),
        .reset_p     (reset),
        .raddr       (1'b0),
        .rdata       (data0),
        .wen_p       (wen0),
        .waddr_p     (1'b0),
        .wdata_p     (vc_write_data)
    );

    vc_RAM_rst_1w1r_pf #(
        .DATA_SZ     (VC_TAG_SZ),
        .ENTRIES     (1),
        .ADDR_SZ     (1),
        .RESET_VALUE (0)
    ) vc_tag0 (
        .clk         (clk),
        .reset_p     (reset),
        .raddr       (1'b0),
        .rdata       (tag_entry0),
        .wen_p       (wen0),
        .waddr_p     (1'b0),
        .wdata_p     (write_tag_entry)
    );

    vc_RAM_rst_1w1r_pf #(
        .DATA_SZ     (`BLK_SIZE),
        .ENTRIES     (1),
        .ADDR_SZ     (1),
        .RESET_VALUE (0)
    ) vc_data1 (
        .clk         (clk),
        .reset_p     (reset),
        .raddr       (1'b0),
        .rdata       (data1),
        .wen_p       (wen1),
        .waddr_p     (1'b0),
        .wdata_p     (vc_write_data)
    );

    vc_RAM_rst_1w1r_pf #(
        .DATA_SZ     (VC_TAG_SZ),
        .ENTRIES     (1),
        .ADDR_SZ     (1),
        .RESET_VALUE (0)
    ) vc_tag1 (
        .clk         (clk),
        .reset_p     (reset),
        .raddr       (1'b0),
        .rdata       (tag_entry1),
        .wen_p       (wen1),
        .waddr_p     (1'b0),
        .wdata_p     (write_tag_entry)
    );

endmodule

`endif
