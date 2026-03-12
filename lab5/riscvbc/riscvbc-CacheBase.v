//====================================================================================
// Cache Base Design - Corrected & Patched Implementation (I-cache only behavior)
//====================================================================================

`ifndef RISCV_CACHE_BASE_V
`define RISCV_CACHE_BASE_V

`include "riscvbc-CacheMsg.v"
`include "vc-RAMs.v"

module riscv_CacheBase (
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

wire [2:0] state;
wire       type;
wire       tag_match;
wire       valid_bit;
wire       dirty_bit;
wire [3:0] refill_counter;

riscv_CacheBaseDpath dpath
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

    .type                  (type),
    .tag_match             (tag_match),      
    .valid_bit             (valid_bit),
    .dirty_bit             (dirty_bit),        
    .refill_counter        (refill_counter)     
);

riscv_CacheBaseCtrl ctrl
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
    .tag_match             (tag_match),          
    .valid_bit             (valid_bit),
    .dirty_bit             (dirty_bit),      
    .refill_counter        (refill_counter),        
      
    .state                 (state),
    .memreq_en             (memreq_en),
    .tag_wen               (tag_wen),
    .data_wen              (data_wen),    
    .write_data_mux_sel    (write_data_mux_sel),
    .miss                  (miss),    
    .refill_cnt_en         (refill_cnt_en),    
    .refill_cnt_clr        (refill_cnt_clr)
);

endmodule

//------------------------------------------------------------------------
// Datapath
//------------------------------------------------------------------------

module riscv_CacheBaseDpath (
    input         clk,
    input         reset,

    // msg
    input  [`VC_MEM_REQ_MSG_SZ(32,32)-1:0] memreq_msg,
    input  [`VC_MEM_RESP_MSG_SZ(32)-1:0]   cacheresp_msg,
    output [`VC_MEM_RESP_MSG_SZ(32)-1:0]   memresp_msg,
    output [`VC_MEM_REQ_MSG_SZ(32,32)-1:0] cachereq_msg,

    // control signals
    input      [2:0]  state,               
    input             memreq_en,           
    input             tag_wen,             
    input             data_wen,            
    input             write_data_mux_sel,  
    input             miss,                
    input             refill_cnt_en,       
    input             refill_cnt_clr,      

    output            type,                
    output            tag_match,           
    output            valid_bit,           
    output            dirty_bit,           
    output reg [3:0]  refill_counter       
);

localparam IDLE           = 3'b000;
localparam READ_CACHE     = 3'b001;
localparam UPDATE_CACHE   = 3'b010;
localparam READ_MEM_REQ   = 3'b011;
localparam READ_MEM_RESP  = 3'b100;
localparam DONE           = 3'b101;

//------------------------------------------------------------------------
// Parse CPU memreq_msg
//------------------------------------------------------------------------

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

// Address breakdown - current and latched
wire [`OFF_BITS-1:0] offset_current = memreq_addr[`OFF_BITS-1:0];
wire [`IDX_BITS-1:0] index_current  = memreq_addr[`OFF_BITS+`IDX_BITS-1:`OFF_BITS];
wire [`TAG_BITS-1:0] tag_current    = memreq_addr[31:`OFF_BITS+`IDX_BITS];

wire [`OFF_BITS-1:0] offset = memreq_addr_reg[`OFF_BITS-1:0];
wire [`IDX_BITS-1:0] index  = memreq_addr_reg[`OFF_BITS+`IDX_BITS-1:`OFF_BITS];
wire [`TAG_BITS-1:0] tag    = memreq_addr_reg[31:`OFF_BITS+`IDX_BITS];

// Use the in-flight request index after the request has been accepted.
// Reading the current bus address during READ_CACHE can mismatch the
// latched tag compare and corrupt the fetch stream on longer benchmarks.
wire [`IDX_BITS-1:0] ram_raddr =
    (state == IDLE) ? index_current : index;

//------------------------------------------------------------------------
// I-cache RAM outputs
//------------------------------------------------------------------------

wire [22:0]          read_tagS;
wire [`BLK_SIZE-1:0] read_data;

// Extract tag and status bits - [22]=valid, [21]=dirty, [20:0]=tag
wire [`TAG_BITS-1:0] read_tag  = read_tagS[`TAG_BITS-1:0];
assign               valid_bit = read_tagS[22];
assign               dirty_bit = read_tagS[21];

assign tag_match = (tag == read_tag);
assign type      = memreq_type_reg;

// local cache_hit inside datapath
wire cache_hit = valid_bit && tag_match;

// Word and byte offsets
wire [3:0] word_offset = memreq_addr_reg[5:2];
wire [1:0] byte_offset = memreq_addr_reg[1:0];

// Extract word from block
wire [31:0] hit_word  = read_data   >> ({word_offset, 5'b0});   // word_offset*32
wire [31:0] miss_word = refill_data >> ({word_offset, 5'b0});   // word_offset*32

//------------------------------------------------------------------------
// Read hit/miss data path
//------------------------------------------------------------------------

reg [31:0] read_data_hit;
always @(*) begin
    case (memreq_len_reg)
        2'b01: read_data_hit = {24'b0, hit_word[byte_offset*8 +: 8]};          // byte
        2'b10: read_data_hit = {16'b0, hit_word[(byte_offset[1]*16) +: 16]};   // halfword
        2'b11: read_data_hit = { 8'b0, hit_word[byte_offset*8 +: 24]};         // 3 bytes
        2'b00: read_data_hit = hit_word;                                       // word
        default: read_data_hit = 32'b0;
    endcase
end

reg [31:0] read_data_miss;
always @(*) begin
    case (memreq_len_reg)
        2'b01: read_data_miss = {24'b0, miss_word[byte_offset*8 +: 8]};
        2'b10: read_data_miss = {16'b0, miss_word[(byte_offset[1]*16) +: 16]};
        2'b11: read_data_miss = { 8'b0, miss_word[byte_offset*8 +: 24]};
        2'b00: read_data_miss = miss_word;
        default: read_data_miss = 32'b0;
    endcase
end

// Refill data accumulator
reg [`BLK_SIZE-1:0] refill_data;

//------------------------------------------------------------------------
// Write hit/miss data path (保留結構，但 Base 當 I-cache 時實際上只會用 refill path)
//------------------------------------------------------------------------

reg [`BLK_SIZE-1:0] write_data_hit;
always @(*) begin
    // Base I-cache: 不會真的處理 WRITE，先保留原結構
    write_data_hit = read_data;
    case (memreq_len_reg)
        2'b01:
            write_data_hit[({word_offset, 5'b0} + {byte_offset, 3'b0}) +: 8]
              = memreq_data_reg[7:0];
        2'b10:
            write_data_hit[({word_offset, 5'b0} + {byte_offset[1], 4'b0}) +: 16]
              = memreq_data_reg[15:0];
        2'b11:
            write_data_hit[({word_offset, 5'b0} + {byte_offset, 3'b0}) +: 24]
              = memreq_data_reg[23:0];
        2'b00:
            write_data_hit[{word_offset, 5'b0} +: 32]
              = memreq_data_reg[31:0];
        default: ;
    endcase
end

reg [`BLK_SIZE-1:0] write_data_miss;
always @(*) begin
    write_data_miss = refill_data;
    if (memreq_type_reg == `WRITE) begin
        case (memreq_len_reg)
            2'b01:
                write_data_miss[({word_offset, 5'b0} + {byte_offset, 3'b0}) +: 8]
                  = memreq_data_reg[7:0];
            2'b10:
                write_data_miss[({word_offset, 5'b0} + {byte_offset[1], 4'b0}) +: 16]
                  = memreq_data_reg[15:0];
            2'b11:
                write_data_miss[({word_offset, 5'b0} + {byte_offset, 3'b0}) +: 24]
                  = memreq_data_reg[23:0];
            2'b00:
                write_data_miss[{word_offset, 5'b0} +: 32]
                  = memreq_data_reg[31:0];
            default: ;
        endcase
    end
end

wire [`BLK_SIZE-1:0] write_data_mux_out = 
    (write_data_mux_sel) ? write_data_miss : write_data_hit;

// Write tag+status: [22]=valid, [21]=dirty, [20:0]=tag
// Base I-cache: dirty 一律 0
wire [22:0] write_tagS = {1'b1, 1'b0, tag};

//------------------------------------------------------------------------
// Sequential logic
//------------------------------------------------------------------------

// Store CPU request when accepted
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

// Store evicted block when miss（目前未使用，保留）
reg [`BLK_SIZE-1:0] read_data_reg;
reg [22:0]          read_tagS_reg;
always @(posedge clk) begin
    if (reset) begin
        read_data_reg <= {`BLK_SIZE{1'b0}};
        read_tagS_reg <= 23'b0;
    end
    else if (miss) begin
        read_data_reg <= read_data;
        read_tagS_reg <= read_tagS;
    end
end

// Refill counter
always @(posedge clk) begin
    if (reset) begin
        refill_counter <= 4'd0;
    end
    else if (refill_cnt_clr) begin
        refill_counter <= 4'd0;
    end 
    else if (refill_cnt_en) begin
        refill_counter <= refill_counter + 4'd1;
    end
end

// Refill data accumulation
always @(posedge clk) begin
    if (reset) begin
        refill_data <= {`BLK_SIZE{1'b0}};
    end 
    else if (refill_cnt_en) begin
        refill_data[refill_counter*32 +: 32] <= cacheresp_data;
    end
end

//------------------------------------------------------------------------
// FSM output messages
//------------------------------------------------------------------------

reg [`VC_MEM_RESP_MSG_SZ(32)-1:0]   memresp_msg_reg; 
reg [`VC_MEM_REQ_MSG_SZ(32,32)-1:0] cachereq_msg_reg;

always @( state or cache_hit or type or memreq_len_reg or read_data_hit
        or memreq_addr_reg or refill_counter or memreq_type_reg
        or read_data_miss ) begin
    // default: all zero
    memresp_msg_reg  = {`VC_MEM_RESP_MSG_SZ(32){1'b0}};
    cachereq_msg_reg = {`VC_MEM_REQ_MSG_SZ(32,32){1'b0}};

    case (state)
        IDLE: begin
            // nothing
        end

        // HIT：在 READ_CACHE state 直接回傳 read_data_hit
        READ_CACHE: begin
            if (cache_hit && (type == `READ)) begin
                memresp_msg_reg[`VC_MEM_RESP_MSG_TYPE_FIELD(32)] = `READ;
                memresp_msg_reg[`VC_MEM_RESP_MSG_LEN_FIELD(32)]  = memreq_len_reg;
                memresp_msg_reg[`VC_MEM_RESP_MSG_DATA_FIELD(32)] = read_data_hit;
            end
        end

        // MISS：發出對 memory 的讀請求，block 內逐字讀
        READ_MEM_REQ: begin
            cachereq_msg_reg[`VC_MEM_REQ_MSG_TYPE_FIELD(32,32)] = `READ;
            cachereq_msg_reg[`VC_MEM_REQ_MSG_ADDR_FIELD(32,32)] = 
                {memreq_addr_reg[31:6], refill_counter[3:0], 2'b00};
            cachereq_msg_reg[`VC_MEM_REQ_MSG_LEN_FIELD(32,32)]  = 2'b00; // 4 bytes
            cachereq_msg_reg[`VC_MEM_REQ_MSG_DATA_FIELD(32,32)] = 32'b0;
        end

        READ_MEM_RESP: begin
            cachereq_msg_reg[`VC_MEM_REQ_MSG_TYPE_FIELD(32,32)] = `READ;
            cachereq_msg_reg[`VC_MEM_REQ_MSG_ADDR_FIELD(32,32)] = 
                {memreq_addr_reg[31:6], refill_counter[3:0], 2'b00};
            cachereq_msg_reg[`VC_MEM_REQ_MSG_LEN_FIELD(32,32)]  = 2'b00;
            cachereq_msg_reg[`VC_MEM_REQ_MSG_DATA_FIELD(32,32)] = 32'b0;
        end

        UPDATE_CACHE: begin
            // only writing RAMs, no external messages
        end

        // MISS：在 DONE 回傳 read_data_miss（refill 後的資料）
        DONE: begin
            memresp_msg_reg[`VC_MEM_RESP_MSG_TYPE_FIELD(32)] = memreq_type_reg;
            memresp_msg_reg[`VC_MEM_RESP_MSG_LEN_FIELD(32)]  = memreq_len_reg;
            memresp_msg_reg[`VC_MEM_RESP_MSG_DATA_FIELD(32)] = read_data_miss;
        end

        default: begin
            memresp_msg_reg  = {`VC_MEM_RESP_MSG_SZ(32){1'b0}};
            cachereq_msg_reg = {`VC_MEM_REQ_MSG_SZ(32,32){1'b0}};
        end
    endcase
end

assign memresp_msg  = memresp_msg_reg;
assign cachereq_msg = cachereq_msg_reg;

//------------------------------------------------------------------------
// I-cache RAM modules
//------------------------------------------------------------------------

vc_RAM_rst_1w1r_pf #(
    .DATA_SZ     (`BLK_SIZE),
    .ENTRIES     (1<<`IDX_BITS),
    .ADDR_SZ     (`IDX_BITS),
    .RESET_VALUE (0)
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
    .DATA_SZ     (23),
    .ENTRIES     (1<<`IDX_BITS),
    .ADDR_SZ     (`IDX_BITS),
    .RESET_VALUE (0)
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

//------------------------------------------------------------------------
// Control Logic
//------------------------------------------------------------------------

module riscv_CacheBaseCtrl (
    input         clk,
    input         reset,

    input          memreq_val,
    output         memreq_rdy,  
    output         memresp_val,
    input          memresp_rdy,    
    output         cachereq_val,
    input          cachereq_rdy,
    input          cacheresp_val,
    output         cacheresp_rdy,
   
    input          type,                
    input          tag_match,           
    input          valid_bit,           
    input          dirty_bit,           
    input   [3:0]  refill_counter,      

    output  [2:0]  state,               
    output         memreq_en,           
    output         tag_wen,             
    output         data_wen,            
    output         write_data_mux_sel,  
    output         miss,                
    output         refill_cnt_en,       
    output         refill_cnt_clr       
); 

assign memreq_en = memreq_val && memreq_rdy;

localparam IDLE           = 3'b000;
localparam READ_CACHE     = 3'b001;
localparam UPDATE_CACHE   = 3'b010;
localparam READ_MEM_REQ   = 3'b011;
localparam READ_MEM_RESP  = 3'b100;
localparam DONE           = 3'b101;

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

wire cache_hit = valid_bit && tag_match;

//------------------------------------------------------------------------
// State transition logic
//------------------------------------------------------------------------

always @(*) begin
    case (curr_state)
        IDLE: begin
            next_state = memreq_val ? READ_CACHE : IDLE;
        end

        // PATCH：HIT 完全留在 READ_CACHE，只在 miss 才進 READ_MEM_REQ
        READ_CACHE: begin
            if (cache_hit) begin
                // 等待接收端把這筆 response 收走
                next_state = memresp_rdy ? IDLE : READ_CACHE;
            end
            else begin
                next_state = READ_MEM_REQ;
            end
        end

        READ_MEM_REQ: begin
            next_state = cachereq_rdy ? READ_MEM_RESP : READ_MEM_REQ;
        end

        READ_MEM_RESP: begin
            if (cacheresp_val) begin
                if (refill_counter == 4'd15)
                    next_state = UPDATE_CACHE;
                else
                    next_state = READ_MEM_REQ;
            end
            else begin
                next_state = READ_MEM_RESP;
            end
        end

        UPDATE_CACHE: begin
            next_state = DONE;
        end

        // DONE 只用在 miss path
        DONE: begin
            next_state = memresp_rdy ? IDLE : DONE;
        end

        default: next_state = IDLE;
    endcase
end

//------------------------------------------------------------------------
// Control outputs
//------------------------------------------------------------------------

reg memreq_rdy_reg;   
reg memresp_val_reg;  
reg cachereq_val_reg; 
reg cacheresp_rdy_reg;

reg tag_wen_reg;
reg data_wen_reg;
reg write_data_mux_sel_reg;
reg refill_cnt_en_reg;
reg refill_cnt_clr_reg;
reg miss_reg;

// Miss detection pulse
always @(*) begin
    miss_reg = 1'b0;
    if (curr_state == READ_CACHE && !cache_hit)
        miss_reg = 1'b1;
end

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

    case (curr_state)
        IDLE: begin
            memreq_rdy_reg     = 1'b1;
            refill_cnt_clr_reg = 1'b1;
        end

        // HIT：在 READ_CACHE 發 memresp_val
        READ_CACHE: begin
            if (cache_hit && (type == `READ)) begin
                memresp_val_reg = 1'b1;
                memreq_rdy_reg  = 1'b0;
            end
        end

        READ_MEM_REQ: begin
            cachereq_val_reg  = 1'b1;
            cacheresp_rdy_reg = 1'b1;
        end

        READ_MEM_RESP: begin
            cacheresp_rdy_reg = 1'b1;
            refill_cnt_en_reg = cacheresp_val;
        end

        UPDATE_CACHE: begin
            tag_wen_reg            = 1'b1;
            data_wen_reg           = 1'b1;
            write_data_mux_sel_reg = (prev_state == READ_MEM_RESP) ? 1'b1 : 1'b0;
        end

        // MISS：在 DONE 發 memresp_val
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
assign miss               = miss_reg;

endmodule

`endif  /* RISCV_CACHE_BASE_V */
