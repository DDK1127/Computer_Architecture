//=========================================================================
// riscv-test4.S
//=========================================================================
// Scenario where riscvlong achieves higher IPC than riscvooo
//
// This test demonstrates cases where the in-order processor is actually
// faster than the out-of-order processor due to:
// 1. ROB overhead (allocation/commit cycles)
// 2. Structural hazards (writeback port conflicts)
// 3. Additional pipeline stages
// 4. Short dependency chains where OoO benefits are minimal

#include "riscv-macros.h"

        TEST_RISCV_BEGIN

        //-----------------------------------------------------------------
        // Test 1: Tight dependency chain (no parallelism to exploit)
        //-----------------------------------------------------------------
        
        li    x10, 1
        
        // Long dependency chain: each instruction depends on previous
        // OoO cannot help here because there's no independent work
        // But OoO adds overhead: ROB alloc + commit stage
        addi  x10, x10, 1       // x10 = 2
        addi  x10, x10, 1       // x10 = 3 (depends on prev)
        addi  x10, x10, 1       // x10 = 4 (depends on prev)
        addi  x10, x10, 1       // x10 = 5 (depends on prev)
        addi  x10, x10, 1       // x10 = 6 (depends on prev)
        addi  x10, x10, 1       // x10 = 7 (depends on prev)
        
        TEST_CHECK_EQ( x10, 7 )
        
        // WHY SLOWER?
        // - In-order: Each ADDI takes 1 cycle, ~7 cycles total
        // - OoO: Each ADDI + ROB overhead, plus commit delay, ~9-10 cycles
        
        //-----------------------------------------------------------------
        // Test 2: Multiple functional units complete simultaneously
        //-----------------------------------------------------------------
        
        li    x11, 5
        li    x12, 3
        la    x20, tdat
        li    x21, 100
        
        // Start operations that complete at same time
        mul   x1, x11, x11      // Completes cycle 4 (MUL pipe)
        mul   x2, x12, x12      // Completes cycle 4 (MUL pipe blocked!)
        lw    x3, 0(x20)        // Completes cycle 2 (MEM pipe)
        addi  x4, x21, 1        // Completes cycle 1 (ALU pipe)
        
        // All want to writeback, but only 1 WB port!
        // OoO has structural hazard stalls
        
        TEST_CHECK_EQ( x1, 25 )
        TEST_CHECK_EQ( x2, 9 )
        TEST_CHECK_EQ( x4, 101 )
        
        // WHY SLOWER?
        // - In-order: Executes serially but predictably
        // - OoO: Writeback conflicts cause stalls (stall_wb_hazard)
        //        Only one instruction can write per cycle

        //-----------------------------------------------------------------
        // Test 3: Simple sequential ALU operations
        //-----------------------------------------------------------------
        
        li    x5, 10
        li    x6, 20
        li    x7, 30
        li    x8, 40
        
        // All independent, all 1-cycle ALU ops
        add   x15, x5, x6       // 30
        add   x16, x7, x8       // 70
        add   x17, x15, x16     // 100
        
        TEST_CHECK_EQ( x17, 100 )
        
        // WHY NOT FASTER?
        // - In-order: Simple pipeline, minimal control overhead
        // - OoO: ROB allocation, scoreboard check, bypass mux overhead
        //        Added complexity doesn't help for simple programs

        //-----------------------------------------------------------------
        // Test 4: ROB bypass latency penalty
        //-----------------------------------------------------------------
        
        li    x25, 7
        
        // Fast operation produces result
        addi  x9, x25, 3        // x9 = 10 (in ROB)
        
        // Immediate use (needs ROB bypass)
        addi  x10, x9, 1        // x10 = 11 (bypass from ROB)
        addi  x11, x10, 1       // x11 = 12 (bypass from ROB)
        
        TEST_CHECK_EQ( x11, 12 )
        
        // WHY SLOWER?
        // - In-order: Direct bypass from W stage, 0 extra cycles
        // - OoO: Must read from ROB data array, potential mux delay
        //        ROB[slot] lookup adds critical path delay

        //-----------------------------------------------------------------
        // Test 5: No speculation benefit (no branches)
        //-----------------------------------------------------------------
        
        // This processor has NO branch prediction/speculation
        // So OoO provides no benefit for control flow
        
        li    x12, 0
        
        addi  x12, x12, 1
        addi  x12, x12, 1
        addi  x12, x12, 1
        addi  x12, x12, 1
        addi  x12, x12, 1
        
        TEST_CHECK_EQ( x12, 5 )
        
        // WHY NO BENEFIT?
        // OoO excels at: 1) Hiding long latencies with parallel work
        //                2) Speculative execution past branches
        // This test has neither, so OoO overhead dominates

        //-----------------------------------------------------------------
        // Summary for Lab Report
        //-----------------------------------------------------------------
        //
        // SCENARIOS WHERE IN-ORDER IS FASTER:
        //
        // 1. TIGHT DEPENDENCY CHAINS
        //    - No independent instructions to execute out-of-order
        //    - ROB overhead (alloc + commit) adds pure latency
        //    - Example: x = ((((x+1)+1)+1)+1)
        //
        // 2. STRUCTURAL HAZARDS
        //    - Multiple pipes complete simultaneously
        //    - Writeback port conflicts cause stalls
        //    - In-order avoids this by sequential execution
        //
        // 3. SIMPLE ALU-HEAVY CODE
        //    - All 1-cycle operations
        //    - No long latencies to hide
        //    - OoO control overhead > benefit
        //
        // 4. BYPASS LATENCY
        //    - ROB bypass adds mux delay vs direct W-stage bypass
        //    - Critical for back-to-back dependencies
        //
        // 5. SHORT PROGRAMS
        //    - OoO benefits accrue over time
        //    - Short tests don't amortize the overhead
        //
        // IRON LAW IMPACT:
        //   IPC = Instructions / Cycles
        //   
        //   In-order: Lower complexity → fewer stalls
        //   OoO:      Higher complexity → structural hazards
        //   
        //   For workloads without parallelism:
        //   OoO adds cycles without reducing instruction count
        //   Result: Lower IPC
        //
        //-----------------------------------------------------------------

        TEST_RISCV_END

        //-----------------------------------------------------------------
        // Test data
        //-----------------------------------------------------------------

        .data
        .align 4
tdat:
        .word 0x00000000