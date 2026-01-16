//=========================================================================
// riscv-test5.S
//=========================================================================
// Test to maximize ROB slot usage
//
// This test fills all 16 ROB slots with independent MUL instructions
// Each MUL takes 4 cycles, so issuing 16 back-to-back will fill the ROB

#include "riscv-macros.h"

        TEST_RISCV_BEGIN

        //-----------------------------------------------------------------
        // Setup: Initialize source registers
        //-----------------------------------------------------------------
        
        li    x10, 2
        li    x11, 3
        li    x12, 5
        li    x13, 7

        //-----------------------------------------------------------------
        // Test: 16 back-to-back MUL instructions
        //-----------------------------------------------------------------
        // Each MUL is independent (no data dependencies)
        // This should fill all 16 ROB slots before any commit
        //-----------------------------------------------------------------
        
        mul   x1,  x10, x11     // 2 * 3 = 6
        mul   x2,  x10, x12     // 2 * 5 = 10
        mul   x3,  x10, x13     // 2 * 7 = 14
        mul   x4,  x11, x12     // 3 * 5 = 15
        
        mul   x5,  x11, x13     // 3 * 7 = 21
        mul   x6,  x12, x13     // 5 * 7 = 35
        mul   x7,  x10, x10     // 2 * 2 = 4
        mul   x8,  x11, x11     // 3 * 3 = 9
        
        mul   x9,  x12, x12     // 5 * 5 = 25
        mul   x14, x13, x13     // 7 * 7 = 49
        mul   x15, x10, x11     // 2 * 3 = 6
        mul   x16, x10, x12     // 2 * 5 = 10
        
        mul   x17, x11, x12     // 3 * 5 = 15
        mul   x18, x12, x13     // 5 * 7 = 35
        mul   x19, x10, x13     // 2 * 7 = 14
        mul   x21, x11, x13     // 3 * 7 = 21

        //-----------------------------------------------------------------
        // Verify all 16 results
        //-----------------------------------------------------------------
        
        TEST_CHECK_EQ( x1,  6  )
        TEST_CHECK_EQ( x2,  10 )
        TEST_CHECK_EQ( x3,  14 )
        TEST_CHECK_EQ( x4,  15 )
        
        TEST_CHECK_EQ( x5,  21 )
        TEST_CHECK_EQ( x6,  35 )
        TEST_CHECK_EQ( x7,  4  )
        TEST_CHECK_EQ( x8,  9  )
        
        TEST_CHECK_EQ( x9,  25 )
        TEST_CHECK_EQ( x14, 49 )
        TEST_CHECK_EQ( x15, 6  )
        TEST_CHECK_EQ( x16, 10 )
        
        TEST_CHECK_EQ( x17, 15 )
        TEST_CHECK_EQ( x18, 35 )
        TEST_CHECK_EQ( x19, 14 )
        TEST_CHECK_EQ( x21, 21 )

        //-----------------------------------------------------------------
        // Additional stress test: Repeat to ensure ROB recycling works
        //-----------------------------------------------------------------
        
        mul   x22, x10, x10     // 2 * 2 = 4
        mul   x23, x11, x11     // 3 * 3 = 9
        mul   x24, x12, x12     // 5 * 5 = 25
        mul   x25, x13, x13     // 7 * 7 = 49
        
        TEST_CHECK_EQ( x22, 4  )
        TEST_CHECK_EQ( x23, 9  )
        TEST_CHECK_EQ( x24, 25 )
        TEST_CHECK_EQ( x25, 49 )

        TEST_RISCV_END