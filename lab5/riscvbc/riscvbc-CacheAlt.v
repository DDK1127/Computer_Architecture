//====================================================================================
// Cache Alt Design (4KB, 2-way set-associative D-cache, write-allocate, write-back)
//====================================================================================

`ifndef RISCV_CACHE_ALT_V
`define RISCV_CACHE_ALT_V

`include "riscvbc-CacheMsg.v"
`include "vc-RAMs.v"

//----------------------------------------------------------------------------
// Top-level wrapper
//----------------------------------------------------------------------------

module riscv_CacheAlt (
    input clk,
    input reset,

    // Processor <-> Cache
    input                                  memreq_val,
    output                                 memreq_rdy,
    input  [`VC_MEM_REQ_MSG_SZ(32,32)-1:0] memreq_msg,

    output                                 memresp_val,
    input                                  memresp_rdy,
    output [`VC_MEM_RESP_MSG_SZ(32)-1:0]   memresp_msg,

    // Cache <-> Main memory
    output                                 cachereq_val,
    input                                  cachereq_rdy,
    output [`VC_MEM_REQ_MSG_SZ(32,32)-1:0] cachereq_msg,

    input                                  cacheresp_val,
    output                                 cacheresp_rdy,
    input  [`VC_MEM_RESP_MSG_SZ(32)-1:0]   cacheresp_msg
);

    // Control wires
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

    wire [2:0] state;
    wire       type;
    wire       tag0_match;
    wire       tag1_match;
    wire       valid0_bit;
    wire       valid1_bit;
    wire       dirty0_bit;
    wire       dirty1_bit;
    wire       victim_way;

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

        .type                  (type),
        .tag0_match            (tag0_match),
        .tag1_match            (tag1_match),
        .valid0_bit            (valid0_bit),
        .valid1_bit            (valid1_bit),
        .dirty0_bit            (dirty0_bit),
        .dirty1_bit            (dirty1_bit),
        .victim_way            (victim_way),
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
        .hit_way_mux_sel       (hit_way_mux_sel)
    );

endmodule

//----------------------------------------------------------------------------
// Datapath
//----------------------------------------------------------------------------

module riscv_CacheAltDpath (
    input         clk,
    input         reset,

    // msg
    input  [`VC_MEM_REQ_MSG_SZ(32,32)-1:0] memreq_msg,
    input  [`VC_MEM_RESP_MSG_SZ(32)-1:0]   cacheresp_msg,
    output [`VC_MEM_RESP_MSG_SZ(32)-1:0]   memresp_msg,
    output [`VC_MEM_REQ_MSG_SZ(32,32)-1:0] cachereq_msg,

    // control
    input      [2:0]  state,
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

    output            type,
    output            tag0_match,
    output            tag1_match,
    output            valid0_bit,
    output            valid1_bit,
    output            dirty0_bit,
    output            dirty1_bit,
    output            victim_way,
    output reg [3:0]  refill_counter,
    output reg [3:0]  wb_counter
);

    localparam IDLE            = 3'b000;
    localparam READ_CACHE      = 3'b001;
    localparam UPDATE_CACHE    = 3'b010;
    localparam READ_MEM_REQ    = 3'b011;
    localparam READ_MEM_RESP   = 3'b100;
    localparam DONE            = 3'b101;
    localparam WRITE_BACK_REQ  = 3'b110;
    localparam WRITE_BACK_RESP = 3'b111;

    //--------------------------------------------------------------------------
    // Parse CPU memreq_msg
    //--------------------------------------------------------------------------

    wire        memreq_type = memreq_msg[`VC_MEM_REQ_MSG_TYPE_FIELD(32,32)];
    wire [31:0] memreq_addr = memreq_msg[`VC_MEM_REQ_MSG_ADDR_FIELD(32,32)];
    wire [1:0]  memreq_len  = memreq_msg[`VC_MEM_REQ_MSG_LEN_FIELD(32,32)];
    wire [31:0] memreq_data = memreq_msg[`VC_MEM_REQ_MSG_DATA_FIELD(32,32)];

    wire [31:0] cacheresp_data = cacheresp_msg[`VC_MEM_RESP_MSG_DATA_FIELD(32)];

    // Latched CPU request fields
    reg        memreq_type_reg;
    reg [31:0] memreq_addr_reg;
    reg [1:0]  memreq_len_reg;
    reg [31:0] memreq_data_reg;

    // Address breakdown
    wire [`OFF_BITS-1:0] offset_current = memreq_addr[`OFF_BITS-1:0];
    wire [`IDX_BITS-1:0] index_current  = memreq_addr[`OFF_BITS+`IDX_BITS-1:`OFF_BITS];
    wire [`TAG_BITS-1:0] tag_current    = memreq_addr[31:`OFF_BITS+`IDX_BITS];

    wire [`OFF_BITS-1:0] offset = memreq_addr_reg[`OFF_BITS-1:0];
    wire [`IDX_BITS-1:0] index  = memreq_addr_reg[`OFF_BITS+`IDX_BITS-1:`OFF_BITS];
    wire [`TAG_BITS-1:0] tag    = memreq_addr_reg[31:`OFF_BITS+`IDX_BITS];

    // RAM read index (current vs latched)
    wire [`IDX_BITS-1:0] ram_raddr = (state == IDLE) ? index_current : index;
    //--------------------------------------------------------------------------
    // Tag/data RAM
    //--------------------------------------------------------------------------

    wire [46:0]            read_tagS;
    wire [`D_SET_SIZE-1:0] read_data;

    // Tag format: [LRU(46) | way1_tagS(45:23) | way0_tagS(22:0)]
    // each way_tagS: {valid(22), dirty(21), tag(20:0)}

    wire [22:0] read_tagS0 = read_tagS[22:0];
    wire [22:0] read_tagS1 = read_tagS[45:23];
    wire        lru_bit    = read_tagS[46];

    wire [`TAG_BITS-1:0] read_tag0  = read_tagS0[`TAG_BITS-1:0];
    assign               dirty0_bit = read_tagS0[`TAG_BITS];      // bit 21
    assign               valid0_bit = read_tagS0[`TAG_BITS+1];    // bit 22

    wire [`TAG_BITS-1:0] read_tag1  = read_tagS1[`TAG_BITS-1:0];
    assign               dirty1_bit = read_tagS1[`TAG_BITS];
    assign               valid1_bit = read_tagS1[`TAG_BITS+1];

    // Data: {way1_block, way0_block}
    wire [`BLK_SIZE-1:0] read_data0 = read_data[`BLK_SIZE-1:0];
    wire [`BLK_SIZE-1:0] read_data1 = read_data[`D_SET_SIZE-1:`BLK_SIZE];

    assign tag0_match = (tag == read_tag0);
    assign tag1_match = (tag == read_tag1);

    // Victim way: prefer invalid; else use LRU
    assign victim_way =
        !valid0_bit ? `WAY0 :
        !valid1_bit ? `WAY1 :
        (lru_bit ? `WAY1 : `WAY0);

    assign type = memreq_type_reg;

    //--------------------------------------------------------------------------
    // Hit / miss datapath
    //--------------------------------------------------------------------------

    wire [3:0] word_offset = memreq_addr_reg[5:2];   // 16 words/block for 64B
    wire [1:0] byte_offset = memreq_addr_reg[1:0];   // byte in word

    // Which way hit
    wire [`BLK_SIZE-1:0] hit_block_data =
        (hit_way_mux_sel) ? read_data1 : read_data0;

    wire [31:0] hit_word =
        hit_block_data >> {word_offset, 5'b0};

    // Refill buffer
    reg [`BLK_SIZE-1:0] refill_data;
    wire [31:0] miss_word =
        refill_data >> {word_offset, 5'b0};

    //--------------------------------------------------------------------------
    // Read hit data
    //--------------------------------------------------------------------------

    reg [31:0] read_data_hit;
    always @(*) begin
        case (memreq_len_reg)
            2'b01: read_data_hit = {24'b0,
                                    hit_word[byte_offset*8 +: 8]};
            2'b10: read_data_hit = {16'b0,
                                    hit_word[byte_offset[1]*16 +: 16]};
            2'b11: read_data_hit = { 8'b0,
                                    hit_word[byte_offset*8 +: 24]};
            2'b00: read_data_hit = hit_word;
            default: read_data_hit = 32'b0;
        endcase
    end

    //--------------------------------------------------------------------------
    // Read miss data (after refill)
    //--------------------------------------------------------------------------

    reg [31:0] read_data_miss;
    always @(*) begin
        case (memreq_len_reg)
            2'b01: read_data_miss = {24'b0,
                                     miss_word[byte_offset*8 +: 8]};
            2'b10: read_data_miss = {16'b0,
                                     miss_word[byte_offset[1]*16 +: 16]};
            2'b11: read_data_miss = { 8'b0,
                                     miss_word[byte_offset*8 +: 24]};
            2'b00: read_data_miss = miss_word;
            default: read_data_miss = 32'b0;
        endcase
    end

    //--------------------------------------------------------------------------
    // Write hit / write miss data
    //--------------------------------------------------------------------------

    reg [`BLK_SIZE-1:0] write_data_hit;
    always @(*) begin
        write_data_hit = hit_block_data;
        case (memreq_len_reg)
            2'b01: begin
                write_data_hit[
                    ({word_offset,5'b0} + {byte_offset,3'b0}) +: 8
                ] = memreq_data_reg[7:0];
            end

            2'b10: begin
                write_data_hit[
                    ({word_offset,5'b0} + {byte_offset[1],4'b0}) +: 16
                ] = memreq_data_reg[15:0];
            end
            2'b11: begin
                write_data_hit[
                    ({word_offset,5'b0} + {byte_offset,3'b0}) +: 24
                ] = memreq_data_reg[23:0];
            end
            2'b00: begin
                write_data_hit[
                    {word_offset,5'b0} +: 32
                ] = memreq_data_reg[31:0];
            end
            default: ;
        endcase
    end

    // combine 2 ways for write hit
    wire [`D_SET_SIZE-1:0] write_data_hit_o =
        (hit_way_mux_sel)
            ? { write_data_hit, read_data0 }
            : { read_data1,    write_data_hit };

    // write miss: modify refill_data
    reg [`BLK_SIZE-1:0] write_data_miss;
    always @(*) begin
        write_data_miss = refill_data;
        if (memreq_type_reg == `WRITE) begin
            case (memreq_len_reg)
                2'b01: begin
                    write_data_miss[
                        ({word_offset,5'b0}+{byte_offset,3'b0}) +: 8
                    ] = memreq_data_reg[7:0];
                end
                2'b10: begin
                    write_data_miss[
                        ({word_offset,5'b0}+{byte_offset[1],4'b0}) +: 16
                    ] = memreq_data_reg[15:0];
                end
                2'b11: begin
                    write_data_miss[
                        ({word_offset,5'b0}+{byte_offset,3'b0}) +: 24
                    ] = memreq_data_reg[23:0];
                end
                2'b00: begin
                    write_data_miss[
                        {word_offset,5'b0} +: 32
                    ] = memreq_data_reg[31:0];
                end
                default: ;
            endcase
        end
    end

    //--------------------------------------------------------------------------
    // Miss bookkeeping: victim/survivor snapshot
    //--------------------------------------------------------------------------

    reg [`BLK_SIZE-1:0] read_data0_reg;
    reg [`BLK_SIZE-1:0] read_data1_reg;
    reg [22:0]          read_tagS0_reg;
    reg [22:0]          read_tagS1_reg;
    reg                 victim_way_reg;

    always @(posedge clk) begin
        if (reset) begin
            read_data0_reg <= {`BLK_SIZE{1'b0}};
            read_data1_reg <= {`BLK_SIZE{1'b0}};
            read_tagS0_reg <= 23'b0;
            read_tagS1_reg <= 23'b0;
            victim_way_reg <= 1'b0;
        end
        else if (miss) begin
            read_data0_reg <= read_data0;
            read_data1_reg <= read_data1;
            read_tagS0_reg <= read_tagS0;
            read_tagS1_reg <= read_tagS1;
            victim_way_reg <= victim_way;
        end
    end

    wire [`BLK_SIZE-1:0] victim_block =
        victim_way_reg ? read_data1_reg : read_data0_reg;

    wire [`BLK_SIZE-1:0] survivor_block =
        victim_way_reg ? read_data0_reg : read_data1_reg;

    wire [22:0] victim_tagS =
        victim_way_reg ? read_tagS1_reg : read_tagS0_reg;

    wire [22:0] survivor_tagS =
        victim_way_reg ? read_tagS0_reg : read_tagS1_reg;

    wire [`BLK_SIZE-1:0] way0_new_miss =
        (victim_way_reg == `WAY0) ? write_data_miss : survivor_block;

    wire [`BLK_SIZE-1:0] way1_new_miss =
        (victim_way_reg == `WAY1) ? write_data_miss : survivor_block;

    wire [`D_SET_SIZE-1:0] write_data_miss_o =
        { way1_new_miss, way0_new_miss };

    // final write data to data RAM
    wire [`D_SET_SIZE-1:0] write_data_mux_out =
        (write_data_mux_sel) ? write_data_miss_o : write_data_hit_o;

    //--------------------------------------------------------------------------
    // Tag update + LRU
    //--------------------------------------------------------------------------

    wire [22:0] curr_tagS0 =
        write_data_mux_sel ? read_tagS0_reg : read_tagS0;

    wire [22:0] curr_tagS1 =
        write_data_mux_sel ? read_tagS1_reg : read_tagS1;

    wire        update_way =
        write_data_mux_sel ? victim_way_reg : hit_way_mux_sel;

    reg [22:0] write_tagS0;
    reg [22:0] write_tagS1;
    reg        write_lru;

    always @(*) begin
        write_tagS0 = curr_tagS0;
        write_tagS1 = curr_tagS1;
        // write_lru   = 1'b0;

        // [FIX] Dirty bit logic:
        // On Write (Hit or Miss/Refill): Dirty = 1
        // On Read Miss (Refill): Dirty = 0
        // We need to differentiate between updating a HIT (keep old dirty) vs MISS (reset dirty)
        
        if (update_way == `WAY0) begin
            // 判斷是否為 Refill (Miss) 造成的寫入
            // write_data_mux_sel 為 1 代表來自 Refill (Miss), 為 0 代表來自 Hit
            
            write_tagS0 = { 1'b1, // Valid
                            (memreq_type_reg == `WRITE) ? 1'b1 :      // Write 總是 Dirty
                            (write_data_mux_sel)        ? 1'b0 :      // Read Miss Refill -> Clean
                                                          curr_tagS0[21], // Read Hit -> Keep Dirty Status
                            tag };
            write_lru   = 1'b1;  // way1 is LRU
        end
        else begin
            write_tagS1 = { 1'b1,
                            (memreq_type_reg == `WRITE) ? 1'b1 :
                            (write_data_mux_sel)        ? 1'b0 :
                                                          curr_tagS1[21],
                            tag };
            write_lru   = 1'b0;  // way0 is LRU
        end
    end

    wire [46:0] write_tagS = { write_lru, write_tagS1, write_tagS0 };

    //--------------------------------------------------------------------------
    // Refill / write-back address + data
    //--------------------------------------------------------------------------

    // refill one word (32b) per memory beat
    wire [31:0] refill_addr =
        { memreq_addr_reg[31:6], refill_counter[3:0], 2'b00 };

    // evict tag & set index
    wire [`TAG_BITS-1:0] evict_tag = victim_tagS[`TAG_BITS-1:0];

    wire [31:0] wb_addr =
        { evict_tag,
          memreq_addr_reg[`OFF_BITS+`IDX_BITS-1:`OFF_BITS],
          wb_counter[3:0],
          2'b00 };

    wire [31:0] wb_data =
        victim_block[ wb_counter*32 +: 32 ];

    //--------------------------------------------------------------------------
    // Sequential: store request, counters, refill_data
    //--------------------------------------------------------------------------

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
            refill_data[ refill_counter*32 +: 32 ] <= cacheresp_data;
    end

    //--------------------------------------------------------------------------
    // Output messages to CPU / memory
    //--------------------------------------------------------------------------

    reg [`VC_MEM_RESP_MSG_SZ(32)-1:0]   memresp_msg_reg;
    reg [`VC_MEM_REQ_MSG_SZ(32,32)-1:0] cachereq_msg_reg;

    wire cache_hit =
        (valid0_bit && tag0_match) ||
        (valid1_bit && tag1_match);

    always @(*) begin
        memresp_msg_reg  = {`VC_MEM_RESP_MSG_SZ(32){1'b0}};
        cachereq_msg_reg = {`VC_MEM_REQ_MSG_SZ(32,32){1'b0}};

        case (state)
            IDLE: begin
            end

            READ_CACHE: begin
                if (cache_hit && (type == `READ)) begin
                    memresp_msg_reg[`VC_MEM_RESP_MSG_TYPE_FIELD(32)] = `READ;
                    memresp_msg_reg[`VC_MEM_RESP_MSG_LEN_FIELD(32)]  = memreq_len_reg;
                    memresp_msg_reg[`VC_MEM_RESP_MSG_DATA_FIELD(32)] = read_data_hit;
                end
            end

            WRITE_BACK_REQ,
            WRITE_BACK_RESP: begin
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
                    (memreq_type_reg == `READ) ? read_data_miss : 32'b0;
            end

            default: ;
        endcase
    end

    assign memresp_msg  = memresp_msg_reg;
    assign cachereq_msg = cachereq_msg_reg;

    //--------------------------------------------------------------------------
    // RAM instances
    //--------------------------------------------------------------------------

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
        .wdata_p     (write_data_mux_out)
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
        .wdata_p     (write_tagS)
    );

endmodule

//----------------------------------------------------------------------------
// Control
//----------------------------------------------------------------------------

module riscv_CacheAltCtrl (
    input         clk,
    input         reset,

    // CPU & memory interface
    input          memreq_val,
    output         memreq_rdy,
    output         memresp_val,
    input          memresp_rdy,
    output         cachereq_val,
    input          cachereq_rdy,
    input          cacheresp_val,
    output         cacheresp_rdy,

    input          type,
    input          tag0_match,
    input          tag1_match,
    input          valid0_bit,
    input          valid1_bit,
    input          dirty0_bit,
    input          dirty1_bit,
    input          victim_way,
    input  [3:0]   refill_counter,
    input  [3:0]   wb_counter,

    output [2:0]   state,
    output         memreq_en,
    output         tag_wen,
    output         data_wen,
    output         write_data_mux_sel,
    output         miss,
    output         refill_cnt_en,
    output         refill_cnt_clr,
    output         wb_cnt_en,
    output         wb_cnt_clr,
    output         hit_way_mux_sel
);

    localparam IDLE            = 3'b000;
    localparam READ_CACHE      = 3'b001;
    localparam UPDATE_CACHE    = 3'b010;
    localparam READ_MEM_REQ    = 3'b011;
    localparam READ_MEM_RESP   = 3'b100;
    localparam DONE            = 3'b101;
    localparam WRITE_BACK_REQ  = 3'b110;
    localparam WRITE_BACK_RESP = 3'b111;

    reg [2:0] curr_state, next_state;
    reg [2:0] prev_state;

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

    // hits
    wire hit0      = valid0_bit && tag0_match;
    wire hit1      = valid1_bit && tag1_match;
    wire cache_hit = hit0 | hit1;

    assign hit_way_mux_sel = hit1;

    wire victim_dirty =
        (victim_way == `WAY1) ? dirty1_bit : dirty0_bit;

    // memreq latch enable
    assign memreq_en = memreq_val && memreq_rdy;

    // miss pulse
    reg miss_reg;
    always @(*) begin
        miss_reg = 1'b0;
        if (curr_state == READ_CACHE && !cache_hit && memreq_val)
            miss_reg = 1'b1;
    end
    assign miss = miss_reg;

    // FSM next state
    always @(*) begin
        case (curr_state)
            IDLE: begin
                next_state = memreq_val ? READ_CACHE : IDLE;
            end

            READ_CACHE: begin
                if (cache_hit && (type == `READ))
                    next_state = READ_CACHE;        // read hit served combinationally
                else if (cache_hit && (type == `WRITE))
                    next_state = UPDATE_CACHE;      // write hit
                else if (victim_dirty)
                    next_state = WRITE_BACK_REQ;    // dirty victim → spill
                else
                    next_state = READ_MEM_REQ;      // clean/invalid victim → refill
            end

            WRITE_BACK_REQ:  next_state = WRITE_BACK_RESP;

            WRITE_BACK_RESP: begin
                if (!cacheresp_val)
                    next_state = WRITE_BACK_RESP;
                else if (wb_counter == 4'd15)
                    next_state = READ_MEM_REQ;      // spill done → refill
                else
                    next_state = WRITE_BACK_REQ;    // next word
            end

            READ_MEM_REQ:    next_state = READ_MEM_RESP;

            READ_MEM_RESP: begin
                if (!cacheresp_val)
                    next_state = READ_MEM_RESP;
                else if (refill_counter == 4'd15)
                    next_state = UPDATE_CACHE;      // block full
                else
                    next_state = READ_MEM_REQ;      // next word
            end

            UPDATE_CACHE:    next_state = DONE;

            DONE: begin
                next_state = memresp_rdy ? IDLE : DONE;
            end

            default:         next_state = IDLE;
        endcase
    end

    // outputs
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

            WRITE_BACK_REQ: begin
                cachereq_val_reg = 1'b1;
            end

            WRITE_BACK_RESP: begin
                cachereq_val_reg  = 1'b1;
                cacheresp_rdy_reg = 1'b1;
                if (cacheresp_val)
                    wb_cnt_en_reg = 1'b1;
            end

            READ_MEM_REQ: begin
                cachereq_val_reg = 1'b1;
            end

            READ_MEM_RESP: begin
                cachereq_val_reg  = 1'b1;
                cacheresp_rdy_reg = 1'b1;
                if (cacheresp_val)
                    refill_cnt_en_reg = 1'b1;
            end

            UPDATE_CACHE: begin
                tag_wen_reg            = 1'b1;
                data_wen_reg           = 1'b1;
                write_data_mux_sel_reg = (prev_state == READ_MEM_RESP);
            end

            DONE: begin
                memresp_val_reg = 1'b1;
            end

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

endmodule

`endif  // RISCV_CACHE_ALT_V
