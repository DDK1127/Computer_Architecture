//========================================================================
// riscv-mulhu.S
// Unsigned × Unsigned Multiply High (MULHU)
//========================================================================

#include "riscv-macros.h"

        TEST_RISCV_BEGIN

        //--------------------------------------------------------------------
        // 基本運算測試
        //--------------------------------------------------------------------

        // Zero and one operands

        TEST_RR_OP( mulhu,  0,  0, 0 )
        TEST_RR_OP( mulhu,  0,  1, 0 )
        TEST_RR_OP( mulhu,  1,  0, 0 )
        TEST_RR_OP( mulhu,  1,  1, 0 )

        // Positive operands (unsigned)
        TEST_RR_OP( mulhu,  42,   13,       0 )
        TEST_RR_OP( mulhu,  716,  89,       0 )
        TEST_RR_OP( mulhu,  65535, 65535,   0 )       // 16-bit max
        TEST_RR_OP( mulhu,  0xffffffff, 0x2, 0x1 )     // upper 32 bits
        TEST_RR_OP( mulhu,  0xffffffff, 0xffffffff, 0xfffffffe )

        //--------------------------------------------------------------------
        // Boundary / 特殊案例
        //--------------------------------------------------------------------

        // High-bit patterns
        TEST_RR_OP( mulhu, 0x80000000, 0x00000002, 0x00000001 )
        TEST_RR_OP( mulhu, 0x80000000, 0x80000000, 0x40000000 )
        TEST_RR_OP( mulhu, 0xffffffff, 0x00000001, 0x00000000 )
        TEST_RR_OP( mulhu, 0xffffffff, 0x00000002, 0x00000001 )

        //--------------------------------------------------------------------
        // Source/Destination overlap tests
        //--------------------------------------------------------------------

        TEST_RR_SRC0_EQ_DEST( mulhu, 13, 11, 0 )
        TEST_RR_SRC1_EQ_DEST( mulhu, 14, 11, 0 )
        TEST_RR_SRC0_EQ_SRC1( mulhu, 15, 0 )
        TEST_RR_SRCS_EQ_DEST( mulhu, 16, 0 )

        //--------------------------------------------------------------------
        // Bypassing tests
        //--------------------------------------------------------------------

        TEST_RR_DEST_BYP( 0, mulhu, 13, 11, 0 )
        TEST_RR_DEST_BYP( 1, mulhu, 14, 11, 0 )
        TEST_RR_DEST_BYP( 2, mulhu, 15, 11, 0 )
        TEST_RR_DEST_BYP( 3, mulhu, 16, 11, 0 )
        TEST_RR_DEST_BYP( 4, mulhu, 17, 11, 0 )

        TEST_RR_SRC01_BYP( 0, 0, mulhu, 13, 11, 0 )
        TEST_RR_SRC01_BYP( 0, 1, mulhu, 14, 11, 0 )
        TEST_RR_SRC01_BYP( 0, 2, mulhu, 15, 11, 0 )
        TEST_RR_SRC01_BYP( 0, 3, mulhu, 16, 11, 0 )
        TEST_RR_SRC01_BYP( 0, 4, mulhu, 17, 11, 0 )

        TEST_RR_SRC01_BYP( 1, 0, mulhu, 13, 11, 0 )
        TEST_RR_SRC01_BYP( 1, 1, mulhu, 14, 11, 0 )
        TEST_RR_SRC01_BYP( 2, 0, mulhu, 15, 11, 0 )

        TEST_RR_SRC10_BYP( 0, 0, mulhu, 13, 11, 0 )
        TEST_RR_SRC10_BYP( 0, 1, mulhu, 14, 11, 0 )
        TEST_RR_SRC10_BYP( 0, 2, mulhu, 15, 11, 0 )
        TEST_RR_SRC10_BYP( 0, 3, mulhu, 16, 11, 0 )
        TEST_RR_SRC10_BYP( 0, 4, mulhu, 17, 11, 0 )

        TEST_RR_SRC10_BYP( 1, 0, mulhu, 13, 11, 0 )
        TEST_RR_SRC10_BYP( 1, 1, mulhu, 14, 11, 0 )
        TEST_RR_SRC10_BYP( 2, 0, mulhu, 15, 11, 0 )

        //--------------------------------------------------------------------
        // Random pattern examples
        //--------------------------------------------------------------------

        TEST_RR_OP( mulhu, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_OP( mulhu, 0xdeadbeef, 0x10000000, 0x0deadbee )
        TEST_RR_OP( mulhu, 0x678abc5d, 0x089aaccd, 0x037ae53c )
        TEST_RR_OP( mulhu, 0x678abc5d, 0x889aaccd, 0x3740436a )
        TEST_RR_OP( mulhu, 0xdeadbeef, 0xdeadbeef, 0xc1b1cd12 )


        TEST_RISCV_END
