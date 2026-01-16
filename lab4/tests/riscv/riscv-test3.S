//=========================================================================
// riscv-test3.S
//=========================================================================
// Write-After-Write (WAW) scenario that works correctly on both processors
//
// This test demonstrates a WAW hazard where two instructions write to
// the same register, but enough time passes between them that both
// processors handle it correctly.
//
// KEY INSIGHT: If there's sufficient separation (cycles) between the two
// writes, even I2O2 works because:
// - First write completes and commits before second write starts
// - No actual WAW conflict occurs at runtime
//
// The ROB ensures correctness by enforcing in-order commit regardless.

#include "riscv-macros.h"

        TEST_RISCV_BEGIN

        //-----------------------------------------------------------------
        // WAW Test 1: Sufficient separation (works on both)
        //-----------------------------------------------------------------
        
        li    x10, 5
        li    x11, 3
        
        // First write to x1 (completes in 4 cycles)
        mul   x1, x10, x11      // x1 = 15
        
        // Add enough independent instructions to create separation
        addi  x12, x10, 1       // 1 cycle
        addi  x13, x11, 1       // 1 cycle
        addi  x14, x12, 1       // 1 cycle
        addi  x15, x13, 1       // 1 cycle
        
        // Second write to x1 (after first one commits)
        addi  x1, x10, 10       // x1 = 15
        
        // Final value should be 15 from second write
        TEST_CHECK_EQ( x1, 15 )
        
        // Verify intermediate values computed correctly
        TEST_CHECK_EQ( x12, 6 )
        TEST_CHECK_EQ( x13, 4 )

        //-----------------------------------------------------------------
        // WAW Test 2: ALU then MUL (different latencies)
        //-----------------------------------------------------------------
        
        li    x20, 10
        
        // Fast ALU operation writes x2
        addi  x2, x20, 5        // x2 = 15 (1 cycle)
        
        // Several independent ops for separation
        addi  x21, x20, 1
        addi  x22, x20, 2
        addi  x23, x20, 3
        
        // Slow MUL operation writes x2
        mul   x2, x20, x20      // x2 = 100 (4 cycles)
        
        // Final value should be 100
        TEST_CHECK_EQ( x2, 100 )

        //-----------------------------------------------------------------
        // WAW Test 3: Memory ops with separation
        //-----------------------------------------------------------------
        
        la    x24, tdat
        li    x25, 0xAAAA
        li    x26, 0xBBBB
        
        // First store
        sw    x25, 0(x24)
        
        // Separation via independent ops
        addi  x27, x25, 1
        addi  x28, x26, 1
        
        // Second store to same location
        sw    x26, 0(x24)
        
        // Load should get second stored value
        lw    x3, 0(x24)
        TEST_CHECK_EQ( x3, 0xBBBB )

        //-----------------------------------------------------------------
        // WAW Test 4: Chain of overwrites (all with separation)
        //-----------------------------------------------------------------
        
        li    x4, 1             // x4 = 1
        nop
        nop
        addi  x4, x4, 1         // x4 = 2
        nop
        nop
        addi  x4, x4, 1         // x4 = 3
        nop
        nop
        addi  x4, x4, 1         // x4 = 4
        
        TEST_CHECK_EQ( x4, 4 )

        //-----------------------------------------------------------------
        // WAW Test 5: Explain why this works on both processors
        //-----------------------------------------------------------------
        // 
        // EXPLANATION (for report):
        // These WAW scenarios work on both I2O2 and I2OI because:
        //
        // 1. TEMPORAL SEPARATION: Sufficient cycles between writes mean
        //    the first write completes AND commits before the second 
        //    write even starts executing.
        //
        // 2. I2O2 perspective:
        //    - First MUL(x1) executes in cycles 0-3
        //    - First MUL(x1) commits out-of-order (maybe cycle 4-5)
        //    - Independent ops fill cycles 4-7
        //    - Second ADDI(x1) starts cycle 8
        //    - No conflict because first write is done
        //
        // 3. I2OI perspective:
        //    - ROB enforces in-order commit
        //    - First write: allocate ROB[0], fill, commit in order
        //    - Second write: allocate ROB[N], fill, commit after ROB[0]
        //    - Always correct due to in-order commit
        //
        // 4. KEY CONDITION: Time between writes > latency of first write
        //    If: (separation cycles) >= (first_write_latency + commit_delay)
        //    Then: No actual hazard occurs
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