//=========================================================================
// riscv-dualfetch-kill.S
//=========================================================================

#include "riscv-macros.h"

        TEST_RISCV_BEGIN

        //-----------------------------------------------------------------
        // If a taken branch is fetched in slot 0, the instruction in slot 1
        // must be killed and must not update architectural state.
        //-----------------------------------------------------------------

        li    x2, 0
        .align 3
branch_pair:
        beq   x0, x0, branch_target
        addi  x2, x2, 1
        j     _fail

branch_target:
        TEST_CHECK_EQ( x2, 0 )

        //-----------------------------------------------------------------
        // The same requirement applies to jumps in slot 0.
        //-----------------------------------------------------------------

        li    x3, 0
        .align 3
jump_pair:
        jal   x1, jump_target
        addi  x3, x3, 1
        j     _fail

jump_target:
        la    x4, jump_pair
        addi  x4, x4, 4
        li    x29, __LINE__
        bne   x1, x4, _fail
        TEST_CHECK_EQ( x3, 0 )

        TEST_RISCV_END
