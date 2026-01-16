# mul_tests_tc32.py
import sys, random

MASK32 = 0xffffffff
MASK64 = 0xffffffffffffffff

def sx32(x):  # 32-bit signed value
    x &= MASK32
    return x if x < 0x80000000 else x - 0x100000000

def zx32(x):  # 32-bit unsigned value
    return x & MASK32

def mul_lo(a, b):
    # RISC-V MUL：有號×有號，回低 32 位（二補數表示）
    p = (sx32(a) * sx32(b)) & MASK64
    return p & MASK32

def mulh(a, b):
    # RISC-V MULH：有號×有號，高 32 位（二補數表示）
    p = (sx32(a) * sx32(b)) & MASK64
    return (p >> 32) & MASK32

def mulhu(a, b):
    # RISC-V MULHU：無號×無號，高 32 位（視為無號，但輸出仍用 32-bit 二補數十六進位）
    p = (zx32(a) * zx32(b)) & MASK64
    return (p >> 32) & MASK32

def mulhsu(a, b):
    # RISC-V MULHSU：有號×無號，高 32 位
    p = (sx32(a) * zx32(b)) & MASK64
    return (p >> 32) & MASK32

def hx32(x):  # 固定 8 碼小寫十六進位
    return f"0x{(x & MASK32):08x}"

def print_case(a, b, tag=None):
    if tag is not None:
        print(f"Test {tag}:")
    ua, ub = zx32(a), zx32(b)
    print(f"  a={hx32(ua)}, b={hx32(ub)}")
    print(f"    mul    expected={hx32(mul_lo(a,b))}")
    print(f"    mulh   expected={hx32(mulh(a,b))}")
    print(f"    mulhu  expected={hx32(mulhu(a,b))}")
    print(f"    mulhsu expected={hx32(mulhsu(a,b))}")
    print()

def parse_hex32(s):
    return int(s, 16)  # 允許含或不含 0x

def main(argv):
    if len(argv) == 3:
        # 單組：兩個 16 進位
        a = parse_hex32(argv[1])
        b = parse_hex32(argv[2])
        print_case(a, b)
    elif len(argv) == 2 and argv[1].startswith("-r"):
        # 隨機模式：-rN，例如 -r10
        try:
            n = int(argv[1][2:])
        except ValueError:
            print("Use: -rN 例如 -r10"); return
        random.seed(0x5566)
        for i in range(n):
            a = random.randint(0, MASK32)
            b = random.randint(0, MASK32)
            print_case(a, b, i)
    elif len(argv) == 3 and argv[1] == "-f":
        # 讀檔模式：每行兩個 hex，用空白或逗號分隔
        path = argv[2]
        with open(path) as f:
            i = 0
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"): continue
                parts = [p for p in line.replace(","," ").split() if p]
                if len(parts) < 2: continue
                a = parse_hex32(parts[0]); b = parse_hex32(parts[1])
                print_case(a, b, i); i += 1
    else:
        print("Usage:")
        print("  python3 mul_tests_tc32.py <hexA> <hexB>")
        print("  python3 mul_tests_tc32.py -rN          # 產生 N 筆隨機")
        print("  python3 mul_tests_tc32.py -f <file>    # 檔案每行兩個 hex")

if __name__ == "__main__":
    main(sys.argv)
