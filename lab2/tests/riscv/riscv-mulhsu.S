//========================================================================
// riscv-mulhsu.S
// Signed x Unsigned Multiply High (MULHSU)
//========================================================================

#include "riscv-macros.h"

        TEST_RISCV_BEGIN

        //--------------------------------------------------------------------
        // Arithmetic tests
        //--------------------------------------------------------------------

        // Zero and one operands
        TEST_RR_OP( mulhsu,  0,  0, 0 )
        TEST_RR_OP( mulhsu,  0,  1, 0 )
        TEST_RR_OP( mulhsu,  1,  0, 0 )
        TEST_RR_OP( mulhsu,  1,  1, 0 )

        // Signed x Unsigned
        TEST_RR_OP( mulhsu,   42,         13,          0 )        
        TEST_RR_OP( mulhsu,  -42,         13, 0xffffffff )     
        TEST_RR_OP( mulhsu,   13, 0x80000000, 0x00000006 )   
        TEST_RR_OP( mulhsu,  -13, 0x80000000, 0xfffffff9 ) 
        TEST_RR_OP( mulhsu,   -1, 0xffffffff, 0xffffffff ) 

        //--------------------------------------------------------------------
        // Boundary cases
        //--------------------------------------------------------------------

        TEST_RR_OP( mulhsu, 0x7fffffff, 0x00000002, 0x00000000 )
        TEST_RR_OP( mulhsu, 0x80000000, 0x00000002, 0xffffffff ) 
        TEST_RR_OP( mulhsu, 0x80000000, 0xffffffff, 0x80000000 ) 
        TEST_RR_OP( mulhsu, 0xffffffff, 0x00000001, 0xffffffff ) 
        TEST_RR_OP( mulhsu, 0xffffffff, 0x00000002, 0xffffffff )

        //--------------------------------------------------------------------
        // Source/Destination overlap tests
        //--------------------------------------------------------------------

        TEST_RR_SRC0_EQ_DEST( mulhsu, 13, 11, 0 )
        TEST_RR_SRC1_EQ_DEST( mulhsu, 14, 11, 0 )
        TEST_RR_SRC0_EQ_SRC1( mulhsu, 15, 0 )
        TEST_RR_SRCS_EQ_DEST( mulhsu, 16, 0 )

        //--------------------------------------------------------------------
        // Bypassing tests
        //--------------------------------------------------------------------

        TEST_RR_DEST_BYP( 0, mulhsu, 13, 11, 0 )
        TEST_RR_DEST_BYP( 1, mulhsu, 14, 11, 0 )
        TEST_RR_DEST_BYP( 2, mulhsu, 15, 11, 0 )
        TEST_RR_DEST_BYP( 3, mulhsu, 16, 11, 0 )
        TEST_RR_DEST_BYP( 4, mulhsu, 17, 11, 0 )

        TEST_RR_SRC01_BYP( 0, 0, mulhsu, 13, 11, 0 )
        TEST_RR_SRC01_BYP( 0, 1, mulhsu, 14, 11, 0 )
        TEST_RR_SRC01_BYP( 0, 2, mulhsu, 15, 11, 0 )
        TEST_RR_SRC01_BYP( 0, 3, mulhsu, 16, 11, 0 )
        TEST_RR_SRC01_BYP( 0, 4, mulhsu, 17, 11, 0 )

        TEST_RR_SRC01_BYP( 1, 0, mulhsu, 13, 11, 0 )
        TEST_RR_SRC01_BYP( 1, 1, mulhsu, 14, 11, 0 )
        TEST_RR_SRC01_BYP( 2, 0, mulhsu, 15, 11, 0 )

        TEST_RR_SRC10_BYP( 0, 0, mulhsu, 13, 11, 0 )
        TEST_RR_SRC10_BYP( 0, 1, mulhsu, 14, 11, 0 )
        TEST_RR_SRC10_BYP( 0, 2, mulhsu, 15, 11, 0 )
        TEST_RR_SRC10_BYP( 0, 3, mulhsu, 16, 11, 0 )
        TEST_RR_SRC10_BYP( 0, 4, mulhsu, 17, 11, 0 )

        TEST_RR_SRC10_BYP( 1, 0, mulhsu, 13, 11, 0 )
        TEST_RR_SRC10_BYP( 1, 1, mulhsu, 14, 11, 0 )
        TEST_RR_SRC10_BYP( 2, 0, mulhsu, 15, 11, 0 )

        //--------------------------------------------------------------------
        // Random / pattern mix
        //--------------------------------------------------------------------

        TEST_RR_OP( mulhsu, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_OP( mulhsu, 0xdeadbeef, 0x10000000, 0xfdeadbee )

        TEST_RISCV_END
