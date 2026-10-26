import os
import math

INT_MIN = -2147483648
INT_MAX = 2147483647
UINT_MAX = 4294967295

def as_u32(val):
    return val & UINT_MAX

def as_i32(val):
    v = val & UINT_MAX
    return v if v <= INT_MAX else v - (UINT_MAX + 1)

def as_hex(val):
    return f"{as_u32(val):08x}"

def c_div(a, b):
    if b == 0: return as_i32(UINT_MAX)
    if a == INT_MIN and b == -1: return INT_MIN
    sign = -1 if (a < 0) ^ (b < 0) else 1
    return sign * (abs(a) // abs(b))

def c_rem(a, b):
    if b == 0: return a
    if a == INT_MIN and b == -1: return 0
    return a - c_div(a, b) * b

def generate_vectors(f):
    def write_op(op, *args):
        f.write(f"{op} " + " ".join(as_hex(a) for a in args) + "\n")

    # 1. qmul
    f.write("# qmul A_raw B_raw Expected_raw\n")
    qmul_cases = [
        (INT_MIN, INT_MIN), 
        (-1, 1), (-1, -1), (0, 0),
        (INT_MAX, INT_MAX), (1 << 16, 1 << 16)
    ]
    for a, b in qmul_cases:
        res = (a * b) >> 16
        write_op("qmul", a, b, res)

    # 2. rcp
    f.write("\n# qrcp X_raw Expected_raw\n")
    rcp_cases = [0, 1, -1, 2, -2, 1 << 31, -65536, INT_MIN, INT_MAX]
    for x in rcp_cases:
        if x == 0: res = INT_MAX
        else:
            res = (1 << 32) // x
            if res > INT_MAX: res = INT_MAX
            elif res < INT_MIN: res = INT_MIN
        write_op("qrcp", x, res)

    # 3. sqrt
    f.write("\n# qsqrt X_raw Expected_raw\n")
    sqrt_base_k = [1, 2, 255, 256, 46340]
    sqrt_cases = [0, 1, -1, -65536, INT_MIN, INT_MAX]
    for k in sqrt_base_k:
        x = k * k
        sqrt_cases.extend([x - 1, x, x + 1])
    
    for x in sorted(list(set(sqrt_cases))):
        res = 0 if x <= 0 else math.isqrt(x << 16)
        write_op("qsqrt", x, res)

    # 4. rsqrt (村上さんの新仕様: floor(2^24 / sqrt(x))
    f.write("\n# qrsqrt X_raw Expected_raw\n")
    rsqrt_cases = [0, 1, -1, INT_MIN, INT_MAX] + sqrt_cases
    for x in sorted(list(set(rsqrt_cases))):
        if x <= 0:
            res = 0
        else:
            # 途中でsqrtを切り捨てない正確な r <= 2^24 / sqrt(x) の最大整数
            res = math.isqrt((1 << 48) // x)
        write_op("qrsqrt", x, res)

    # 5. i32_div / i32_rem
    f.write("\n# i32_div A_raw B_raw Expected_raw\n")
    f.write("# i32_rem A_raw B_raw Expected_raw\n")
    div_cases = [
        (10, 0), (INT_MIN, -1), (-10, -3), (-10, 3), (10, -3), (INT_MAX, 2)
    ]
    for a, b in div_cases:
        write_op("i32_div", a, b, c_div(a, b))
        write_op("i32_rem", a, b, c_rem(a, b))

    # 6. dot3
    f.write("\n# dot3 ax ay az bx by bz Expected_raw\n")
    dot3_cases = [
        ((INT_MAX, INT_MAX, INT_MAX), (1, 1, 1)),
        ((1<<16, 2<<16, 3<<16), (1<<16, 2<<16, 3<<16)),
        ((-1<<16, -2<<16, 3<<16), (1<<16, -2<<16, 3<<16)),
    ]
    for (ax, ay, az), (bx, by, bz) in dot3_cases:
        dot = ((ax * bx) >> 16) + ((ay * by) >> 16) + ((az * bz) >> 16)
        write_op("dot3", ax, ay, az, bx, by, bz, dot)

    # 7. i32_abs (絶対値関数)
    f.write("\n# i32_abs X_raw Expected_raw\n")
    abs_cases = [0, 1, -1, INT_MAX, INT_MIN]
    for x in abs_cases:
        # C言語の abs(INT_MIN) は -(-2147483648) = 2147483648 -> 0x80000000 となる
        res = as_u32(abs(x)) if x != INT_MIN else (1 << 31)
        write_op("i32_abs", x, res)

if __name__ == "__main__":
    output_dir = "ref"
    os.makedirs(output_dir, exist_ok=True)
    filepath = os.path.join(output_dir, "qmath_vectors.txt")
    with open(filepath, "w") as f:
        generate_vectors(f)
    print(f"Generated {filepath} successfully.")