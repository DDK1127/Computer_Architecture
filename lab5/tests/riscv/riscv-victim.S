//=========================================================================
// riscv-victim.S
//=========================================================================

#include "riscv-macros.h"

        TEST_RISCV_BEGIN

        la    x2, block0
        li    x3, 0x11111111
        sw    x3, 0(x2)

        la    x2, block1
        li    x3, 0x22222222
        sw    x3, 0(x2)

        la    x2, block2
        li    x3, 0x33333333
        sw    x3, 0(x2)

        la    x2, block3
        li    x3, 0x44444444
        sw    x3, 0(x2)

        la    x2, block0
        lw    x4, 0(x2)
        TEST_CHECK_EQ( x4, 0x11111111 )

        la    x2, block1
        lw    x4, 0(x2)
        TEST_CHECK_EQ( x4, 0x22222222 )

        la    x2, block2
        lw    x4, 0(x2)
        TEST_CHECK_EQ( x4, 0x33333333 )

        la    x2, block3
        lw    x4, 0(x2)
        TEST_CHECK_EQ( x4, 0x44444444 )

        la    x2, block0
        li    x3, 0xaaaaaaaa
        sw    x3, 0(x2)

        la    x2, block1
        li    x3, 0xbbbbbbbb
        sw    x3, 0(x2)

        la    x2, block2
        li    x3, 0xcccccccc
        sw    x3, 0(x2)

        la    x2, block3
        li    x3, 0xdddddddd
        sw    x3, 0(x2)

        la    x2, block0
        lw    x4, 0(x2)
        TEST_CHECK_EQ( x4, 0xaaaaaaaa )

        la    x2, block1
        lw    x4, 0(x2)
        TEST_CHECK_EQ( x4, 0xbbbbbbbb )

        la    x2, block2
        lw    x4, 0(x2)
        TEST_CHECK_EQ( x4, 0xcccccccc )

        la    x2, block3
        lw    x4, 0(x2)
        TEST_CHECK_EQ( x4, 0xdddddddd )

        TEST_RISCV_END

        .section .data
        .align 6

block0: .space 64
        .space 1984
block1: .space 64
        .space 1984
block2: .space 64
        .space 1984
block3: .space 64
