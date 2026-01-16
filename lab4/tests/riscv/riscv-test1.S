//=========================================================================
// riscv-test1.S
//=========================================================================
// Test that fails due to out-of-order commits but passes with ROB
// 
// This test creates a scenario where:
// 1. A MUL instruction (4 cycles) is issued first
// 2. A fast ADD instruction (1 cycle) is issued second
// 3. A dependent instruction uses the result of MUL
//
// Without ROB (I2O2): The ADD might commit before MUL completes, causing
// the dependent instruction to read incorrect value from register file
//
// With ROB (I2OI): Instructions commit in-order, ensuring correctness

#include "riscv-macros.h"

        TEST_RISCV_BEGIN

        //-----------------------------------------------------------------
        // Basic out-of-order commit violation test
        //-----------------------------------------------------------------
        
        // Setup: x10 = 5, x11 = 3
        li    x10, 5
        li    x11, 3
        
        // MUL takes 4 cycles to complete
        // This will be allocated to ROB first but completes last
        mul   x1, x10, x11      // x1 = 5 * 3 = 15 (takes 4 cycles)
        
        // ADD takes 1 cycle to complete
        // This completes before MUL but should not commit first
        addi  x2, x10, 10       // x2 = 5 + 10 = 15 (takes 1 cycle)
        
        // This instruction depends on x1 (MUL result)
        // Without in-order commit, x1 might not be ready yet
        addi  x3, x1, 1         // x3 = 15 + 1 = 16
        
        // Verify results
        TEST_CHECK_EQ( x1, 15 )
        TEST_CHECK_EQ( x2, 15 )
        TEST_CHECK_EQ( x3, 16 )

        //-----------------------------------------------------------------
        // WAW (Write-After-Write) hazard test
        //-----------------------------------------------------------------
        
        // Both instructions write to x4, but they must commit in order
        li    x12, 100
        mul   x4, x10, x10      // x4 = 25 (completes cycle 4)
        addi  x4, x12, 0        // x4 = 100 (completes cycle 1)
        
        // Final value should be 100 (second write)
        // Without ROB, might see 25 if commits are out-of-order
        TEST_CHECK_EQ( x4, 100 )

        //-----------------------------------------------------------------
        // Memory operation ordering test
        //-----------------------------------------------------------------
        
        la    x15, tdat
        li    x13, 0xDEADBEEF
        
        // MUL and SW both write, must maintain order
        mul   x5, x10, x11      // x5 = 15 (4 cycles)
        sw    x13, 0(x15)       // Store to memory (2 cycles)
        lw    x6, 0(x15)        // Load from memory (2 cycles)
        
        // x6 should have the stored value
        TEST_CHECK_EQ( x6, 0xDEADBEEF )
        
        // x5 should have MUL result
        TEST_CHECK_EQ( x5, 15 )

        TEST_RISCV_END

        //-----------------------------------------------------------------
        // Test data
        //-----------------------------------------------------------------

        .data
        .align 4
tdat:
        .word 0x00000000