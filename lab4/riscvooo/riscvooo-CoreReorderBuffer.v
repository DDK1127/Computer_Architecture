//=========================================================================
// 5-Stage RISCV Reorder Buffer  (single-issue, in-order commit)
//=========================================================================

`ifndef RISCV_CORE_REORDERBUFFER_V
`define RISCV_CORE_REORDERBUFFER_V

`include "riscvooo-InstMsg.v" // must define `SLOTS and `LOG_S

module riscv_CoreReorderBuffer
(
  input               clk,
  input               reset,

  // Allocate from Decode
  input               rob_alloc_req_val,
  output              rob_alloc_req_rdy,
  input  [ 4:0]       rob_alloc_req_preg,
  output [`LOG_S-1:0] rob_alloc_resp_slot,

  // Fill from Writeback/Execute-complete
  input               rob_fill_val,
  input  [`LOG_S-1:0] rob_fill_slot,

  // Commit to RF
  output              rob_commit_wen,
  output [`LOG_S-1:0] rob_commit_slot,
  output [ 4:0]       rob_commit_rf_waddr
);

  // ---------------------------------------------
  // Params and state
  // ---------------------------------------------
  localparam S = `SLOTS;
  localparam W = `LOG_S;

  reg               valid   [0:S-1];
  reg               pending [0:S-1];
  reg [4:0]         preg    [0:S-1];
  reg [W-1:0]       head;
  reg [W-1:0]       tail;
  
  // Count of valid entries for better full/empty detection
  reg [W:0]         count;  // Can hold 0 to S

  wire [W-1:0] tail_next = tail + {{(W-1){1'b0}},1'b1};
  wire [W-1:0] head_next = head + {{(W-1){1'b0}},1'b1};

  // Better empty/full detection using count
  wire rob_empty = (count == {(W+1){1'b0}});
  wire rob_full  = (count == S);

  // ---------------------------------------------
  // Combinational outputs
  // ---------------------------------------------
  assign rob_alloc_req_rdy   = !rob_full || head_ready;
  assign rob_alloc_resp_slot = tail;

  wire head_valid = valid[head] && !rob_empty;
  wire head_ready = head_valid && !pending[head];

  assign rob_commit_wen      = head_ready;
  assign rob_commit_slot     = head;
  assign rob_commit_rf_waddr = preg[head];

  // ---------------------------------------------
  // Sequential updates
  // ---------------------------------------------
  integer i;
  
  // Determine what operations occur this cycle
  wire do_commit = head_ready;
  wire do_alloc  = rob_alloc_req_val && rob_alloc_req_rdy;
  wire do_fill   = rob_fill_val;
  
  always @(posedge clk) begin
    if (reset) begin
      head  <= {W{1'b0}};
      tail  <= {W{1'b0}};
      count <= {(W+1){1'b0}};
      for (i = 0; i < S; i = i + 1) begin
        valid[i]   <= 1'b0;
        pending[i] <= 1'b0;
        preg[i]    <= 5'd0;
      end
    end
    else begin
      // Update count based on alloc and commit
      if (do_alloc && !do_commit) begin
        count <= count + {{W{1'b0}},1'b1};
      end
      else if (!do_alloc && do_commit) begin
        count <= count - {{W{1'b0}},1'b1};
      end
      // If both alloc and commit, count stays same
      
      // Fill: mark slot result ready (can happen independently)
      if (do_fill) begin
        pending[rob_fill_slot] <= 1'b0;
      end

      // Commit: retire head if ready
      if (do_commit) begin
        valid[head]   <= 1'b0;
        pending[head] <= 1'b0;  // Reset for cleanliness
        head          <= head_next;
      end

      // Alloc: claim tail if requested and not full
      if (do_alloc) begin
        valid[tail]   <= 1'b1;
        pending[tail] <= 1'b1;
        preg[tail]    <= rob_alloc_req_preg;
        tail          <= tail_next;
      end
    end
  end

endmodule

`endif