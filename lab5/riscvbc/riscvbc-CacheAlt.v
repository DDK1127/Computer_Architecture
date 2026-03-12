//====================================================================================
// Cache Alt Design (4KB, 2-way set-associative D-cache with victim cache)
//====================================================================================

`ifndef RISCV_CACHE_ALT_V
`define RISCV_CACHE_ALT_V

`include "riscvbc-CacheMsg.v"
`include "riscvbc-VictimCache.v"
`include "vc-RAMs.v"

module riscv_CacheAlt (
    input clk,
    input reset,

    input                                  memreq_val,
    output                                 memreq_rdy,
    input  [`VC_MEM_REQ_MSG_SZ(32,32)-1:0] memreq_msg,

    output                                 memresp_val,
    input                                  memresp_rdy,
    output [`VC_MEM_RESP_MSG_SZ(32)-1:0]   memresp_msg,

    output                                 cachereq_val,
    input                                  cachereq_rdy,
    output [`VC_MEM_REQ_MSG_SZ(32,32)-1:0] cachereq_msg,

    input                                  cacheresp_val,
    output                                 cacheresp_rdy,
    input  [`VC_MEM_RESP_MSG_SZ(32)-1:0]   cacheresp_msg
);

    wire       memreq_en;
    wire       tag_wen;
    wire       data_wen;
    wire       write_data_mux_sel;
    wire       miss;
    wire       refill_cnt_en;
    wire       refill_cnt_clr;
    wire       wb_cnt_en;
    wire       wb_cnt_clr;
    wire       hit_way_mux_sel;
    wire       vc_write_en;

    wire [3:0] state;
    wire       type;
    wire       tag0_match;
    wire       tag1_match;
    wire       valid0_bit;
    wire       valid1_bit;
    wire       dirty0_bit;
    wire       dirty1_bit;
    wire       victim_way;
    wire       vc_hit;
    wire       vc_alloc_valid;
    wire       vc_alloc_dirty;

    wire [3:0] refill_counter;
    wire [3:0] wb_counter;

    riscv_CacheAltDpath dpath
    (
        .clk                   (clk),
        .reset                 (reset),
        .memreq_msg            (memreq_msg),
        .cacheresp_msg         (cacheresp_msg),
        .memresp_msg           (memresp_msg),
        .cachereq_msg          (cachereq_msg),
        .state                 (state),
        .memreq_en             (memreq_en),
        .tag_wen               (tag_wen),
        .data_wen              (data_wen),
        .write_data_mux_sel    (write_data_mux_sel),
        .miss                  (miss),
        .refill_cnt_en         (refill_cnt_en),
        .refill_cnt_clr        (refill_cnt_clr),
        .wb_cnt_en             (wb_cnt_en),
        .wb_cnt_clr            (wb_cnt_clr),
        .hit_way_mux_sel       (hit_way_mux_sel),
        .vc_write_en           (vc_write_en),
        .type                  (type),
        .tag0_match            (tag0_match),
        .tag1_match            (tag1_match),
        .valid0_bit            (valid0_bit),
        .valid1_bit            (valid1_bit),
        .dirty0_bit            (dirty0_bit),
        .dirty1_bit            (dirty1_bit),
        .victim_way            (victim_way),
        .vc_hit                (vc_hit),
        .vc_alloc_valid        (vc_alloc_valid),
        .vc_alloc_dirty        (vc_alloc_dirty),
        .refill_counter        (refill_counter),
        .wb_counter            (wb_counter)
    );

    riscv_CacheAltCtrl ctrl
    (
        .clk                   (clk),
        .reset                 (reset),
        .memreq_val            (memreq_val),
        .memreq_rdy            (memreq_rdy),
        .memresp_val           (memresp_val),
        .memresp_rdy           (memresp_rdy),
        .cachereq_val          (cachereq_val),
        .cachereq_rdy          (cachereq_rdy),
        .cacheresp_val         (cacheresp_val),
        .cacheresp_rdy         (cacheresp_rdy),
        .type                  (type),
        .tag0_match            (tag0_match),
        .tag1_match            (tag1_match),
        .valid0_bit            (valid0_bit),
        .valid1_bit            (valid1_bit),
        .dirty0_bit            (dirty0_bit),
        .dirty1_bit            (dirty1_bit),
        .victim_way            (victim_way),
        .vc_hit                (vc_hit),
        .vc_alloc_valid        (vc_alloc_valid),
        .vc_alloc_dirty        (vc_alloc_dirty),
        .refill_counter        (refill_counter),
        .wb_counter            (wb_counter),
        .state                 (state),
        .memreq_en             (memreq_en),
        .tag_wen               (tag_wen),
        .data_wen              (data_wen),
        .write_data_mux_sel    (write_data_mux_sel),
        .miss                  (miss),
        .refill_cnt_en         (refill_cnt_en),
        .refill_cnt_clr        (refill_cnt_clr),
        .wb_cnt_en             (wb_cnt_en),
        .wb_cnt_clr            (wb_cnt_clr),
        .hit_way_mux_sel       (hit_way_mux_sel),
        .vc_write_en           (vc_write_en)
    );

endmodule

module riscv_CacheAltDpath (
    input         clk,
    input         reset,

    input  [`VC_MEM_REQ_MSG_SZ(32,32)-1:0] memreq_msg,
    input  [`VC_MEM_RESP_MSG_SZ(32)-1:0]   cacheresp_msg,
    output [`VC_MEM_RESP_MSG_SZ(32)-1:0]   memresp_msg,
    output [`VC_MEM_REQ_MSG_SZ(32,32)-1:0] cachereq_msg,

    input      [3:0]  state,
    input             memreq_en,
    input             tag_wen,
    input             data_wen,
    input             write_data_mux_sel,
    input             miss,
    input             refill_cnt_en,
    input             refill_cnt_clr,
    input             wb_cnt_en,
    input             wb_cnt_clr,
    input             hit_way_mux_sel,
    input             vc_write_en,

    output            type,
    output            tag0_match,
    output            tag1_match,
    output            valid0_bit,
    output            valid1_bit,
    output            dirty0_bit,
    output            dirty1_bit,
    output            victim_way,
    output            vc_hit,
    output            vc_alloc_valid,
    output            vc_alloc_dirty,
    output reg [3:0]  refill_counter,
    output reg [3:0]  wb_counter
);

    localparam IDLE          = 4'd0;
    localparam READ_CACHE    = 4'd1;
    localparam VC_WB_REQ     = 4'd2;
    localparam VC_WB_RESP    = 4'd3;
    localparam VC_INSTALL    = 4'd4;
    localparam READ_MEM_REQ  = 4'd5;
    localparam READ_MEM_RESP = 4'd6;
    localparam UPDATE_CACHE  = 4'd7;
    localparam VICTIM_SWAP   = 4'd8;
    localparam DONE          = 4'd9;

    wire        memreq_type = memreq_msg[`VC_MEM_REQ_MSG_TYPE_FIELD(32,32)];
    wire [31:0] memreq_addr = memreq_msg[`VC_MEM_REQ_MSG_ADDR_FIELD(32,32)];
    wire [1:0]  memreq_len  = memreq_msg[`VC_MEM_REQ_MSG_LEN_FIELD(32,32)];
    wire [31:0] memreq_data = memreq_msg[`VC_MEM_REQ_MSG_DATA_FIELD(32,32)];

    wire [31:0] cacheresp_data = cacheresp_msg[`VC_MEM_RESP_MSG_DATA_FIELD(32)];

    reg        memreq_type_reg;
    reg [31:0] memreq_addr_reg;
    reg [1:0]  memreq_len_reg;
    reg [31:0] memreq_data_reg;

    wire [`OFF_BITS-1:0] offset_current = memreq_addr[`OFF_BITS-1:0];
    wire [`IDX_BITS-1:0] index_current  = memreq_addr[`OFF_BITS+`IDX_BITS-1:`OFF_BITS];
    wire [`TAG_BITS-1:0] tag_current    = memreq_addr[31:`OFF_BITS+`IDX_BITS];

    wire [`OFF_BITS-1:0] offset = memreq_addr_reg[`OFF_BITS-1:0];
    wire [`IDX_BITS-1:0] index  = memreq_addr_reg[`OFF_BITS+`IDX_BITS-1:`OFF_BITS];
    wire [`TAG_BITS-1:0] tag    = memreq_addr_reg[31:`OFF_BITS+`IDX_BITS];

    wire [`IDX_BITS-1:0] ram_raddr = (state == IDLE) ? index_current : index;

    wire [46:0]            read_tagS;
    wire [`D_SET_SIZE-1:0] read_data;

    wire [22:0] read_tagS0 = read_tagS[22:0];
    wire [22:0] read_tagS1 = read_tagS[45:23];
    wire        lru_bit    = read_tagS[46];

    wire [`TAG_BITS-1:0] read_tag0 = read_tagS0[`TAG_BITS-1:0];
    wire [`TAG_BITS-1:0] read_tag1 = read_tagS1[`TAG_BITS-1:0];

    assign dirty0_bit = read_tagS0[`TAG_BITS];
    assign valid0_bit = read_tagS0[`TAG_BITS+1];
    assign dirty1_bit = read_tagS1[`TAG_BITS];
    assign valid1_bit = read_tagS1[`TAG_BITS+1];

    wire [`BLK_SIZE-1:0] read_data0 = read_data[`BLK_SIZE-1:0];
    wire [`BLK_SIZE-1:0] read_data1 = read_data[`D_SET_SIZE-1:`BLK_SIZE];

    assign tag0_match = (tag == read_tag0);
    assign tag1_match = (tag == read_tag1);

    assign victim_way = !valid0_bit ? `WAY0 :
                        !valid1_bit ? `WAY1 :
                                      (lru_bit ? `WAY1 : `WAY0);

    assign type = memreq_type_reg;

    wire [3:0] word_offset = memreq_addr_reg[5:2];
    wire [1:0] byte_offset = memreq_addr_reg[1:0];

    wire [`BLK_SIZE-1:0] hit_block_data = hit_way_mux_sel ? read_data1 : read_data0;
    wire [31:0] hit_word  = hit_block_data >> {word_offset, 5'b0};

    reg [`BLK_SIZE-1:0] refill_data;
    wire [31:0] miss_word = refill_data >> {word_offset, 5'b0};

    reg [31:0] read_data_hit;
    always @(*) begin
        case (memreq_len_reg)
            2'b01: read_data_hit = {24'b0, hit_word[byte_offset*8 +: 8]};
            2'b10: read_data_hit = {16'b0, hit_word[byte_offset[1]*16 +: 16]};
            2'b11: read_data_hit = { 8'b0, hit_word[byte_offset*8 +: 24]};
            2'b00: read_data_hit = hit_word;
            default: read_data_hit = 32'b0;
        endcase
    end

    reg [31:0] read_data_miss;
    always @(*) begin
        case (memreq_len_reg)
            2'b01: read_data_miss = {24'b0, miss_word[byte_offset*8 +: 8]};
            2'b10: read_data_miss = {16'b0, miss_word[byte_offset[1]*16 +: 16]};
            2'b11: read_data_miss = { 8'b0, miss_word[byte_offset*8 +: 24]};
            2'b00: read_data_miss = miss_word;
            default: read_data_miss = 32'b0;
        endcase
    end

    reg [`BLK_SIZE-1:0] write_data_hit;
    always @(*) begin
        write_data_hit = hit_block_data;
        case (memreq_len_reg)
            2'b01: write_data_hit[({word_offset,5'b0}+{byte_offset,3'b0}) +: 8] = memreq_data_reg[7:0];
            2'b10: write_data_hit[({word_offset,5'b0}+{byte_offset[1],4'b0}) +: 16] = memreq_data_reg[15:0];
            2'b11: write_data_hit[({word_offset,5'b0}+{byte_offset,3'b0}) +: 24] = memreq_data_reg[23:0];
            2'b00: write_data_hit[{word_offset,5'b0} +: 32] = memreq_data_reg[31:0];
            default: ;
        endcase
    end

    wire [`D_SET_SIZE-1:0] write_data_hit_o =
        hit_way_mux_sel ? { write_data_hit, read_data0 }
                        : { read_data1,     write_data_hit };

    reg [`BLK_SIZE-1:0] write_data_miss;
    always @(*) begin
        write_data_miss = refill_data;
        if (memreq_type_reg == `WRITE) begin
            case (memreq_len_reg)
                2'b01: write_data_miss[({word_offset,5'b0}+{byte_offset,3'b0}) +: 8] = memreq_data_reg[7:0];
                2'b10: write_data_miss[({word_offset,5'b0}+{byte_offset[1],4'b0}) +: 16] = memreq_data_reg[15:0];
                2'b11: write_data_miss[({word_offset,5'b0}+{byte_offset,3'b0}) +: 24] = memreq_data_reg[23:0];
                2'b00: write_data_miss[{word_offset,5'b0} +: 32] = memreq_data_reg[31:0];
                default: ;
            endcase
        end
    end

    reg [`BLK_SIZE-1:0] read_data0_reg;
    reg [`BLK_SIZE-1:0] read_data1_reg;
    reg [22:0]          read_tagS0_reg;
    reg [22:0]          read_tagS1_reg;
    reg                 victim_way_reg;
    reg                 serve_from_vc_reg;
    reg [`BLK_SIZE-1:0] vc_hit_data_reg;

    wire [`BLK_SIZE-1:0] victim_block   = victim_way_reg ? read_data1_reg : read_data0_reg;
    wire [`BLK_SIZE-1:0] survivor_block = victim_way_reg ? read_data0_reg : read_data1_reg;
    wire [22:0]          victim_tagS    = victim_way_reg ? read_tagS1_reg : read_tagS0_reg;
    wire [22:0]          survivor_tagS  = victim_way_reg ? read_tagS0_reg : read_tagS1_reg;
    wire                 victim_valid   = victim_tagS[22];

    wire [`BLK_SIZE-1:0] way0_new_miss =
        (victim_way_reg == `WAY0) ? write_data_miss : survivor_block;
    wire [`BLK_SIZE-1:0] way1_new_miss =
        (victim_way_reg == `WAY1) ? write_data_miss : survivor_block;
    wire [`D_SET_SIZE-1:0] write_data_miss_o = { way1_new_miss, way0_new_miss };

    reg [`BLK_SIZE-1:0] write_data_vc;
    always @(*) begin
        write_data_vc = vc_hit_data_reg;
        if (memreq_type_reg == `WRITE) begin
            case (memreq_len_reg)
                2'b01: write_data_vc[({word_offset,5'b0}+{byte_offset,3'b0}) +: 8] = memreq_data_reg[7:0];
                2'b10: write_data_vc[({word_offset,5'b0}+{byte_offset[1],4'b0}) +: 16] = memreq_data_reg[15:0];
                2'b11: write_data_vc[({word_offset,5'b0}+{byte_offset,3'b0}) +: 24] = memreq_data_reg[23:0];
                2'b00: write_data_vc[{word_offset,5'b0} +: 32] = memreq_data_reg[31:0];
                default: ;
            endcase
        end
    end

    reg [31:0] read_data_vc;
    always @(*) begin
        case (memreq_len_reg)
            2'b01: read_data_vc = {24'b0, write_data_vc[({word_offset,5'b0}+{byte_offset,3'b0}) +: 8]};
            2'b10: read_data_vc = {16'b0, write_data_vc[({word_offset,5'b0}+{byte_offset[1],4'b0}) +: 16]};
            2'b11: read_data_vc = { 8'b0, write_data_vc[({word_offset,5'b0}+{byte_offset,3'b0}) +: 24]};
            2'b00: read_data_vc = write_data_vc[{word_offset,5'b0} +: 32];
            default: read_data_vc = 32'b0;
        endcase
    end

    wire [`BLK_SIZE-1:0] way0_new_swap =
        (victim_way_reg == `WAY0) ? write_data_vc : survivor_block;
    wire [`BLK_SIZE-1:0] way1_new_swap =
        (victim_way_reg == `WAY1) ? write_data_vc : survivor_block;
    wire [`D_SET_SIZE-1:0] write_data_swap_o = { way1_new_swap, way0_new_swap };

    wire [`D_SET_SIZE-1:0] cache_write_data =
        (state == VICTIM_SWAP) ? write_data_swap_o :
        (write_data_mux_sel)   ? write_data_miss_o :
                                 write_data_hit_o;

    wire [22:0] update_curr_tagS0 = write_data_mux_sel ? read_tagS0_reg : read_tagS0;
    wire [22:0] update_curr_tagS1 = write_data_mux_sel ? read_tagS1_reg : read_tagS1;
    wire        update_way        = write_data_mux_sel ? victim_way_reg : hit_way_mux_sel;
    wire        update_dirty      = (memreq_type_reg == `WRITE);
    wire        update_lru        = (update_way == `WAY0) ? 1'b1 : 1'b0;

    reg [22:0] write_tagS0_update;
    reg [22:0] write_tagS1_update;
    always @(*) begin
        write_tagS0_update = update_curr_tagS0;
        write_tagS1_update = update_curr_tagS1;
        if (update_way == `WAY0)
            write_tagS0_update = {1'b1, update_dirty, tag};
        else
            write_tagS1_update = {1'b1, update_dirty, tag};
    end

    reg [22:0] write_tagS0_swap;
    reg [22:0] write_tagS1_swap;
    always @(*) begin
        write_tagS0_swap = read_tagS0_reg;
        write_tagS1_swap = read_tagS1_reg;
        if (victim_way_reg == `WAY0)
            write_tagS0_swap = {1'b1, update_dirty, tag};
        else
            write_tagS1_swap = {1'b1, update_dirty, tag};
    end

    wire swap_lru = (victim_way_reg == `WAY0) ? 1'b1 : 1'b0;
    wire [46:0] cache_write_tag =
        (state == VICTIM_SWAP)
            ? { swap_lru,   write_tagS1_swap,   write_tagS0_swap   }
            : { update_lru, write_tagS1_update, write_tagS0_update };

    wire        vc_hit_way;
    wire [`BLK_SIZE-1:0] vc_hit_data;
    wire [22:0]          vc_hit_tag;
    wire                 vc_alloc_way;
    wire [`BLK_SIZE-1:0] vc_alloc_data;
    wire [22:0]          vc_alloc_tag;
    wire [31:0]          vc_alloc_addr;

    assign vc_alloc_valid = vc_alloc_tag[22];
    assign vc_alloc_dirty = vc_alloc_tag[21];

    wire vc_write_way = (state == VICTIM_SWAP) ? vc_hit_way : vc_alloc_way;
    wire [31:0] vc_write_addr =
        { victim_tagS[`TAG_BITS-1:0], index, 6'b0 };
    wire [22:0] vc_write_tag = victim_valid ? victim_tagS : 23'b0;
    wire [`BLK_SIZE-1:0] vc_write_data = victim_block;

    wire [31:0] refill_addr =
        { memreq_addr_reg[31:6], refill_counter[3:0], 2'b00 };

    wire [31:0] wb_addr =
        { vc_alloc_addr[31:6], wb_counter[3:0], 2'b00 };
    wire [31:0] wb_data =
        vc_alloc_data[wb_counter*32 +: 32];

    always @(posedge clk) begin
        if (reset) begin
            memreq_type_reg <= 1'b0;
            memreq_addr_reg <= 32'b0;
            memreq_len_reg  <= 2'b0;
            memreq_data_reg <= 32'b0;
        end
        else if (memreq_en) begin
            memreq_type_reg <= memreq_type;
            memreq_addr_reg <= memreq_addr;
            memreq_len_reg  <= memreq_len;
            memreq_data_reg <= memreq_data;
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            read_data0_reg    <= {`BLK_SIZE{1'b0}};
            read_data1_reg    <= {`BLK_SIZE{1'b0}};
            read_tagS0_reg    <= 23'b0;
            read_tagS1_reg    <= 23'b0;
            victim_way_reg    <= 1'b0;
            serve_from_vc_reg <= 1'b0;
            vc_hit_data_reg   <= {`BLK_SIZE{1'b0}};
        end
        else begin
            if (memreq_en)
                serve_from_vc_reg <= 1'b0;
            if (miss) begin
                read_data0_reg  <= read_data0;
                read_data1_reg  <= read_data1;
                read_tagS0_reg  <= read_tagS0;
                read_tagS1_reg  <= read_tagS1;
                victim_way_reg  <= victim_way;
                if (vc_hit) begin
                    serve_from_vc_reg <= 1'b1;
                    vc_hit_data_reg   <= vc_hit_data;
                end
            end
        end
    end

    always @(posedge clk) begin
        if (reset)
            refill_counter <= 4'd0;
        else if (refill_cnt_clr)
            refill_counter <= 4'd0;
        else if (refill_cnt_en)
            refill_counter <= refill_counter + 4'd1;
    end

    always @(posedge clk) begin
        if (reset)
            wb_counter <= 4'd0;
        else if (wb_cnt_clr)
            wb_counter <= 4'd0;
        else if (wb_cnt_en)
            wb_counter <= wb_counter + 4'd1;
    end

    always @(posedge clk) begin
        if (reset)
            refill_data <= {`BLK_SIZE{1'b0}};
        else if (refill_cnt_en)
            refill_data[refill_counter*32 +: 32] <= cacheresp_data;
    end

    reg [`VC_MEM_RESP_MSG_SZ(32)-1:0]   memresp_msg_reg;
    reg [`VC_MEM_REQ_MSG_SZ(32,32)-1:0] cachereq_msg_reg;

    wire cache_hit =
        (valid0_bit && tag0_match) ||
        (valid1_bit && tag1_match);

    always @(*) begin
        memresp_msg_reg  = {`VC_MEM_RESP_MSG_SZ(32){1'b0}};
        cachereq_msg_reg = {`VC_MEM_REQ_MSG_SZ(32,32){1'b0}};

        case (state)
            READ_CACHE: begin
                if (cache_hit && (type == `READ)) begin
                    memresp_msg_reg[`VC_MEM_RESP_MSG_TYPE_FIELD(32)] = `READ;
                    memresp_msg_reg[`VC_MEM_RESP_MSG_LEN_FIELD(32)]  = memreq_len_reg;
                    memresp_msg_reg[`VC_MEM_RESP_MSG_DATA_FIELD(32)] = read_data_hit;
                end
            end

            VC_WB_REQ,
            VC_WB_RESP: begin
                cachereq_msg_reg[`VC_MEM_REQ_MSG_TYPE_FIELD(32,32)] = `WRITE;
                cachereq_msg_reg[`VC_MEM_REQ_MSG_ADDR_FIELD(32,32)] = wb_addr;
                cachereq_msg_reg[`VC_MEM_REQ_MSG_LEN_FIELD(32,32)]  = 2'b00;
                cachereq_msg_reg[`VC_MEM_REQ_MSG_DATA_FIELD(32,32)] = wb_data;
            end

            READ_MEM_REQ,
            READ_MEM_RESP: begin
                cachereq_msg_reg[`VC_MEM_REQ_MSG_TYPE_FIELD(32,32)] = `READ;
                cachereq_msg_reg[`VC_MEM_REQ_MSG_ADDR_FIELD(32,32)] = refill_addr;
                cachereq_msg_reg[`VC_MEM_REQ_MSG_LEN_FIELD(32,32)]  = 2'b00;
                cachereq_msg_reg[`VC_MEM_REQ_MSG_DATA_FIELD(32,32)] = 32'b0;
            end

            DONE: begin
                memresp_msg_reg[`VC_MEM_RESP_MSG_TYPE_FIELD(32)] = memreq_type_reg;
                memresp_msg_reg[`VC_MEM_RESP_MSG_LEN_FIELD(32)]  = memreq_len_reg;
                memresp_msg_reg[`VC_MEM_RESP_MSG_DATA_FIELD(32)] =
                    (memreq_type_reg == `READ)
                        ? (serve_from_vc_reg ? read_data_vc : read_data_miss)
                        : 32'b0;
            end

            default: ;
        endcase
    end

    assign memresp_msg  = memresp_msg_reg;
    assign cachereq_msg = cachereq_msg_reg;

    vc_RAM_rst_1w1r_pf #(
        .DATA_SZ     (`D_SET_SIZE),
        .ENTRIES     (32),
        .ADDR_SZ     (`IDX_BITS),
        .RESET_VALUE ({`D_SET_SIZE{1'b0}})
    ) _data (
        .clk         (clk),
        .reset_p     (reset),
        .raddr       (ram_raddr),
        .rdata       (read_data),
        .wen_p       (data_wen),
        .waddr_p     (index),
        .wdata_p     (cache_write_data)
    );

    vc_RAM_rst_1w1r_pf #(
        .DATA_SZ     (47),
        .ENTRIES     (32),
        .ADDR_SZ     (`IDX_BITS),
        .RESET_VALUE (47'b0)
    ) _tag (
        .clk         (clk),
        .reset_p     (reset),
        .raddr       (ram_raddr),
        .rdata       (read_tagS),
        .wen_p       (tag_wen),
        .waddr_p     (index),
        .wdata_p     (cache_write_tag)
    );

    riscv_VictimCache victim_cache (
        .clk          (clk),
        .reset        (reset),
        .vc_addr      (memreq_addr_reg),
        .vc_hit       (vc_hit),
        .vc_hit_way   (vc_hit_way),
        .vc_hit_data  (vc_hit_data),
        .vc_hit_tag   (vc_hit_tag),
        .vc_alloc_way (vc_alloc_way),
        .vc_alloc_data(vc_alloc_data),
        .vc_alloc_tag (vc_alloc_tag),
        .vc_alloc_addr(vc_alloc_addr),
        .vc_alloc_valid(vc_alloc_valid),
        .vc_alloc_dirty(vc_alloc_dirty),
        .vc_write_en  (vc_write_en),
        .vc_write_way (vc_write_way),
        .vc_write_addr(vc_write_addr),
        .vc_write_data(vc_write_data),
        .vc_write_tag (vc_write_tag)
    );

endmodule

module riscv_CacheAltCtrl (
    input         clk,
    input         reset,

    input         memreq_val,
    output        memreq_rdy,
    output        memresp_val,
    input         memresp_rdy,
    output        cachereq_val,
    input         cachereq_rdy,
    input         cacheresp_val,
    output        cacheresp_rdy,

    input         type,
    input         tag0_match,
    input         tag1_match,
    input         valid0_bit,
    input         valid1_bit,
    input         dirty0_bit,
    input         dirty1_bit,
    input         victim_way,
    input         vc_hit,
    input         vc_alloc_valid,
    input         vc_alloc_dirty,
    input  [3:0]  refill_counter,
    input  [3:0]  wb_counter,

    output [3:0]  state,
    output        memreq_en,
    output        tag_wen,
    output        data_wen,
    output        write_data_mux_sel,
    output        miss,
    output        refill_cnt_en,
    output        refill_cnt_clr,
    output        wb_cnt_en,
    output        wb_cnt_clr,
    output        hit_way_mux_sel,
    output        vc_write_en
);

    localparam IDLE          = 4'd0;
    localparam READ_CACHE    = 4'd1;
    localparam VC_WB_REQ     = 4'd2;
    localparam VC_WB_RESP    = 4'd3;
    localparam VC_INSTALL    = 4'd4;
    localparam READ_MEM_REQ  = 4'd5;
    localparam READ_MEM_RESP = 4'd6;
    localparam UPDATE_CACHE  = 4'd7;
    localparam VICTIM_SWAP   = 4'd8;
    localparam DONE          = 4'd9;

    reg [3:0] curr_state;
    reg [3:0] next_state;
    reg [3:0] prev_state;

    always @(posedge clk) begin
        if (reset) begin
            curr_state <= IDLE;
            prev_state <= IDLE;
        end
        else begin
            prev_state <= curr_state;
            curr_state <= next_state;
        end
    end

    assign state = curr_state;

    wire hit0 = valid0_bit && tag0_match;
    wire hit1 = valid1_bit && tag1_match;
    wire cache_hit = hit0 || hit1;
    wire victim_line_valid = (victim_way == `WAY1) ? valid1_bit : valid0_bit;

    assign hit_way_mux_sel = hit1;
    assign memreq_en = memreq_val && memreq_rdy;
    assign miss = (curr_state == READ_CACHE) && !cache_hit;

    always @(*) begin
        case (curr_state)
            IDLE:
                next_state = memreq_val ? READ_CACHE : IDLE;

            READ_CACHE: begin
                if (cache_hit && (type == `READ))
                    next_state = READ_CACHE;
                else if (cache_hit && (type == `WRITE))
                    next_state = UPDATE_CACHE;
                else if (vc_hit)
                    next_state = VICTIM_SWAP;
                else if (victim_line_valid && vc_alloc_valid && vc_alloc_dirty)
                    next_state = VC_WB_REQ;
                else if (victim_line_valid)
                    next_state = VC_INSTALL;
                else
                    next_state = READ_MEM_REQ;
            end

            VC_WB_REQ:
                next_state = cachereq_rdy ? VC_WB_RESP : VC_WB_REQ;

            VC_WB_RESP: begin
                if (!cacheresp_val)
                    next_state = VC_WB_RESP;
                else if (wb_counter == 4'd15)
                    next_state = VC_INSTALL;
                else
                    next_state = VC_WB_REQ;
            end

            VC_INSTALL:
                next_state = READ_MEM_REQ;

            READ_MEM_REQ:
                next_state = cachereq_rdy ? READ_MEM_RESP : READ_MEM_REQ;

            READ_MEM_RESP: begin
                if (!cacheresp_val)
                    next_state = READ_MEM_RESP;
                else if (refill_counter == 4'd15)
                    next_state = UPDATE_CACHE;
                else
                    next_state = READ_MEM_REQ;
            end

            UPDATE_CACHE:
                next_state = DONE;

            VICTIM_SWAP:
                next_state = DONE;

            DONE:
                next_state = memresp_rdy ? IDLE : DONE;

            default:
                next_state = IDLE;
        endcase
    end

    reg memreq_rdy_reg;
    reg memresp_val_reg;
    reg cachereq_val_reg;
    reg cacheresp_rdy_reg;
    reg tag_wen_reg;
    reg data_wen_reg;
    reg write_data_mux_sel_reg;
    reg refill_cnt_en_reg;
    reg refill_cnt_clr_reg;
    reg wb_cnt_en_reg;
    reg wb_cnt_clr_reg;
    reg vc_write_en_reg;

    always @(*) begin
        memreq_rdy_reg         = 1'b0;
        memresp_val_reg        = 1'b0;
        cachereq_val_reg       = 1'b0;
        cacheresp_rdy_reg      = 1'b0;
        tag_wen_reg            = 1'b0;
        data_wen_reg           = 1'b0;
        write_data_mux_sel_reg = 1'b0;
        refill_cnt_en_reg      = 1'b0;
        refill_cnt_clr_reg     = 1'b0;
        wb_cnt_en_reg          = 1'b0;
        wb_cnt_clr_reg         = 1'b0;
        vc_write_en_reg        = 1'b0;

        case (curr_state)
            IDLE: begin
                memreq_rdy_reg     = 1'b1;
                refill_cnt_clr_reg = 1'b1;
                wb_cnt_clr_reg     = 1'b1;
            end

            READ_CACHE: begin
                if (cache_hit && (type == `READ)) begin
                    memreq_rdy_reg  = 1'b1;
                    memresp_val_reg = 1'b1;
                end
            end

            VC_WB_REQ: begin
                cachereq_val_reg  = 1'b1;
                cacheresp_rdy_reg = 1'b1;
            end

            VC_WB_RESP: begin
                cacheresp_rdy_reg = 1'b1;
                if (cacheresp_val)
                    wb_cnt_en_reg = 1'b1;
            end

            VC_INSTALL:
                vc_write_en_reg = 1'b1;

            READ_MEM_REQ: begin
                cachereq_val_reg  = 1'b1;
                cacheresp_rdy_reg = 1'b1;
            end

            READ_MEM_RESP: begin
                cacheresp_rdy_reg = 1'b1;
                if (cacheresp_val)
                    refill_cnt_en_reg = 1'b1;
            end

            UPDATE_CACHE: begin
                tag_wen_reg            = 1'b1;
                data_wen_reg           = 1'b1;
                write_data_mux_sel_reg = (prev_state == READ_MEM_RESP);
            end

            VICTIM_SWAP: begin
                tag_wen_reg     = 1'b1;
                data_wen_reg    = 1'b1;
                vc_write_en_reg = 1'b1;
            end

            DONE:
                memresp_val_reg = 1'b1;

            default: ;
        endcase
    end

    assign memreq_rdy         = memreq_rdy_reg;
    assign memresp_val        = memresp_val_reg;
    assign cachereq_val       = cachereq_val_reg;
    assign cacheresp_rdy      = cacheresp_rdy_reg;
    assign tag_wen            = tag_wen_reg;
    assign data_wen           = data_wen_reg;
    assign write_data_mux_sel = write_data_mux_sel_reg;
    assign refill_cnt_en      = refill_cnt_en_reg;
    assign refill_cnt_clr     = refill_cnt_clr_reg;
    assign wb_cnt_en          = wb_cnt_en_reg;
    assign wb_cnt_clr         = wb_cnt_clr_reg;
    assign vc_write_en        = vc_write_en_reg;

endmodule

`endif
