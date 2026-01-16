//=========================================================================
// riscv-test2.S
//=========================================================================
// Test case requiring value to be bypassed from ROB
//
// This test creates scenarios where:
// - An instruction completes (writes to ROB) but hasn't committed yet
// - A dependent instruction needs to read this value via ROB bypass
// - Without ROB bypass, the processor would stall until commit

#include "riscv-macros.h"

        TEST_RISCV_BEGIN

        //-----------------------------------------------------------------
        // ROB bypass test 1: MUL result bypass
        //-----------------------------------------------------------------
        
        li    x10, 7
        li    x11, 3
        
        // MUL completes in 4 cycles, writes to ROB
        mul   x1, x10, x11      // x1 = 21 (in ROB slot 0)
        
        // These instructions depend on x1 before it commits
        // Should bypass from ROB slot 0
        addi  x2, x1, 1         // x2 = 22 (needs x1 from ROB)
        addi  x3, x1, 2         // x3 = 23 (needs x1 from ROB)
        add   x4, x2, x3        // x4 = 45 (needs x2, x3 from ROB)
        
        TEST_CHECK_EQ( x1, 21 )
        TEST_CHECK_EQ( x2, 22 )
        TEST_CHECK_EQ( x3, 23 )
        TEST_CHECK_EQ( x4, 45 )

        //-----------------------------------------------------------------
        // ROB bypass test 2: Multiple functional units
        //-----------------------------------------------------------------
        
        li    x12, 10
        li    x13, 5
        la    x20, tdat
        
        // Start three operations in different pipes
        mul   x5, x12, x13      // MUL pipe: 4 cycles
        lw    x6, 0(x20)        // MEM pipe: 2 cycles
        addi  x7, x12, 1        // ALU pipe: 1 cycle
        
        // Dependent chain through ROB
        add   x8, x7, x7        // x8 = 22 (bypass x7 from ROB)
        add   x9, x8, x5        // x9 = 72 (bypass x8, x5 from ROB)
        
        TEST_CHECK_EQ( x5, 50 )
        TEST_CHECK_EQ( x7, 11 )
        TEST_CHECK_EQ( x8, 22 )
        TEST_CHECK_EQ( x9, 72 )

        //-----------------------------------------------------------------
        // ROB bypass test 3: Back-to-back dependencies
        //-----------------------------------------------------------------
        
        li    x14, 4
        
        // Create a dependency chain
        mul   x10, x14, x14     // x10 = 16
        mul   x11, x10, x14     // x11 = 64 (depends on x10 from ROB)
        mul   x12, x11, x14     // x12 = 256 (depends on x11 from ROB)
        addi  x13, x12, 0       // x13 = 256 (depends on x12 from ROB)
        
        TEST_CHECK_EQ( x10, 16 )
        TEST_CHECK_EQ( x11, 64 )
        TEST_CHECK_EQ( x12, 256 )
        TEST_CHECK_EQ( x13, 256 )

        //-----------------------------------------------------------------
        // ROB bypass test 4: Mixed bypass sources
        //-----------------------------------------------------------------
        
        li    x15, 8
        li    x16, 2
        
        mul   x1, x15, x16      // x1 = 16 (ROB)
        addi  x2, x15, 0        // x2 = 8  (ROB)
        add   x3, x1, x2        // x3 = 24 (bypass both from ROB)
        
        TEST_CHECK_EQ( x3, 24 )

        TEST_RISCV_END

        //-----------------------------------------------------------------
        // Test data
        //-----------------------------------------------------------------

        .data
        .align 4
tdat:
        .word 0x00000000