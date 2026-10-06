# tools/assembler.py
import sys
import re
from asm_types import REG_MAP, OPCODES, PSEUDO_INSTRUCTIONS

UNSUPPORTED_DATA_DIRECTIVES = {
    '.byte', '.half', '.short', '.2byte', '.4byte', '.dword', '.quad',
    '.ascii', '.asciz', '.string', '.zero', '.space', '.skip', '.fill',
}

SAFE_SKIP_DIRECTIVES = {
    '.data', '.globl', '.global', '.section', '.file',
    '.type', '.size', '.ident', '.option', '.attribute',
    '.align', '.p2align', '.balign',
}

def parse_reg(reg_str):
    """'x1' / 'a0' -> 0-31 """
    reg_str = reg_str.strip().lower()
    if re.fullmatch(r'x\d+', reg_str) and int(reg_str[1:]) <= 31:
        return int(reg_str[1:])
    elif reg_str in REG_MAP:
        return REG_MAP[reg_str]
    else:
        raise ValueError(f"Unknown register: {reg_str}")

def parse_literal_or_int(val_str):
    """'-'などを整数に"""
    val_str = str(val_str).strip()
    if val_str.startswith("'") and val_str.endswith("'") and len(val_str) >= 3:
        return ord(val_str[1])
    return int(val_str, 0)

def parse_imm(imm_val_or_str, bits, signed=True):
    """即値 -> 2の補数(範囲外:error)"""
    if isinstance(imm_val_or_str, int):
        val = imm_val_or_str
    else:
        try:
            val = parse_literal_or_int(imm_val_or_str)
        except ValueError:
            raise ValueError(f"Invalid immediate: '{imm_val_or_str}'")

    if signed:
        lo, hi = -(1 << (bits - 1)), (1 << (bits - 1)) - 1
    else:
        lo, hi = 0, (1 << bits) - 1
    if not lo <= val <= hi:
        raise ValueError(f"Immediate {val} out of range ({lo}..{hi})")
    return val & ((1 << bits) - 1)


def resolve_target(tok, current_pc=0, symbol_table=None):
    if symbol_table is None:
        symbol_table = {}
    
    """オフセット"""
    if tok in symbol_table:
        offset = symbol_table[tok] - current_pc
    else:
        try:
            offset = int(tok, 0)
        except ValueError:
            raise ValueError(f"Undefined label: '{tok}'")
    if offset % 2:
        raise ValueError(f"Offset {offset} must be even")
    return offset


def check_args(tokens, n):
    if len(tokens) != n + 1:
        raise ValueError(f"'{tokens[0]}' expects {n} operands, got {len(tokens) - 1}")


def expand_li(rd, imm_str, symbol_table=None):
    if symbol_table is None:
        symbol_table = {}

    if imm_str in symbol_table:
        imm = symbol_table[imm_str]
    else:
        try:
            imm = parse_literal_or_int(imm_str)
        except ValueError:
            raise ValueError(f"Invalid immediate: '{imm_str}'")
    
    if not -(1 << 31) <= imm < (1 << 32):
        raise ValueError(f"li immediate {imm} out of 32-bit range")
    imm = ((imm + (1 << 31)) % (1 << 32)) - (1 << 31)

    if -2048 <= imm <= 2047:
        return [f"addi {rd}, x0, {imm}"]

    lo = ((imm & 0xFFF) ^ 0x800) - 0x800
    hi = ((imm - lo) >> 12) & 0xFFFFF
    lines = [f"lui {rd}, {hi}"]
    if lo != 0:
        lines.append(f"addi {rd}, {rd}, {lo}")
    return lines


def expand_pseudo(line, symbol_table=None):
    """疑似命令の展開"""
    if symbol_table is None:
        symbol_table = {}

    line = line.strip()
    clean_line = line.replace(',', ' ').replace('(', ' ').replace(')', ' ')
    tokens = clean_line.split()
    if not tokens:
        return [line]

    op = tokens[0].lower()
    args = tokens[1:]

    if op == 'call':
        if len(args) != 1:
            raise ValueError(f"'call' expects 1 operands")
        return [f"jal ra, {args[0]}"]

    if op == 'li':
        if len(args) != 2:
            raise ValueError("'li' expects 2 operands")
        return expand_li(args[0], args[1], symbol_table)
    
    if op == 'la':
        if len(args) != 2:
            raise ValueError("'la' expects 2 operands")
        rd, sym = args[0], args[1]
        return [f"auipc {rd}, %pcrel_hi({sym})", f"addi {rd}, {rd}, %pcrel_lo({sym})"]

    if op == 'jal' and len(args) == 1:
        return [f"jal ra, {args[0]}"]

    if op == 'jalr' and len(args) == 1:
        return [f"jalr ra, {args[0]}, 0"]

    if op in PSEUDO_INSTRUCTIONS:
        info = PSEUDO_INSTRUCTIONS[op]
        if len(args) != info['arg_count']:
            raise ValueError(f"Pseudo-instruction '{op}' expects {info['arg_count']} args, got {len(args)}")
        return [info['template'].format(*args)]

    return [line]

def resolve_pcrel(line, current_pc, symbol_table):
    """%pcrel_hi(sym) / %pcrel_lo(sym) を数値に置換する"""
    def repl(m):
        kind, sym = m.group(1), m.group(2).strip()
        if sym not in symbol_table:
            raise ValueError(f"Undefined label: '{sym}'")
        base = current_pc if kind == 'hi' else current_pc - 4
        offset = symbol_table[sym] - base
        if kind == 'hi':
            return str(((offset + 0x800) >> 12) & 0xFFFFF)
        return str(((offset & 0xFFF) ^ 0x800) - 0x800)
    return re.sub(r'%pcrel_(hi|lo)\(([^)]*)\)', repl, line)

def assemble_line(line, current_pc=0, symbol_table=None):
    """基本命令1行 -> 16進数"""
    if symbol_table is None:
        symbol_table = {}

    line = resolve_pcrel(line, current_pc, symbol_table)
    clean_line = line.replace(',', ' ').replace('(', ' ').replace(')', ' ')
    tokens = clean_line.split()
    op = tokens[0].lower()

    if op not in OPCODES:
        raise ValueError(f"Unsupported instruction '{op}'")

    info = OPCODES[op]
    fmt = info['type']

    # R-type
    if fmt == 'R':
        check_args(tokens, 3)
        rd, rs1, rs2 = parse_reg(tokens[1]), parse_reg(tokens[2]), parse_reg(tokens[3])
        val = (info['funct7'] << 25) | (rs2 << 20) | (rs1 << 15) | (info['funct3'] << 12) | (rd << 7) | info['opcode']
        return f"{val:08x}"

    # I-type
    elif fmt == 'I':
        check_args(tokens, 3)
        if '(' in line:   # lw rd, imm(rs1) / jalr rd, imm(rs1) -> [op, rd, imm, rs1]
            rd, imm_s, rs1 = parse_reg(tokens[1]), tokens[2], parse_reg(tokens[3])
        else:             # addi rd, rs1, imm / jalr rd, rs1, imm -> [op, rd, rs1, imm]
            if info['opcode'] == 0x03:
                raise ValueError(f"'{op}' expects rd, imm(rs1)")
            rd, rs1, imm_s = parse_reg(tokens[1]), parse_reg(tokens[2]), tokens[3]

        is_shift = info['imm_bits'] == 5
        imm = parse_imm(imm_s, info['imm_bits'], signed=not is_shift)
        funct7 = info.get('funct7', 0)
        val = (funct7 << 25) | (imm << 20) | (rs1 << 15) | (info['funct3'] << 12) | (rd << 7) | info['opcode']
        return f"{val:08x}"

    # S-type
    elif fmt == 'S':
        if '(' not in line:
            raise ValueError(f"'{op}' expects rs2, imm(rs1)")
        check_args(tokens, 3)   # [sw, rs2, imm, rs1]
        rs2, imm, rs1 = parse_reg(tokens[1]), parse_imm(tokens[2], info['imm_bits']), parse_reg(tokens[3])
        imm_11_5 = (imm >> 5) & 0x7F
        imm_4_0 = imm & 0x1F
        val = (imm_11_5 << 25) | (rs2 << 20) | (rs1 << 15) | (info['funct3'] << 12) | (imm_4_0 << 7) | info['opcode']
        return f"{val:08x}"

    # B-type
    elif fmt == 'B':
        check_args(tokens, 3)
        rs1, rs2 = parse_reg(tokens[1]), parse_reg(tokens[2])
        offset = resolve_target(tokens[3], current_pc, symbol_table)

        imm = parse_imm(offset, info['imm_bits'])
        imm_12   = (imm >> 12) & 0x1
        imm_10_5 = (imm >> 5)  & 0x3F
        imm_4_1  = (imm >> 1)  & 0x0F
        imm_11   = (imm >> 11) & 0x1
        val = (imm_12 << 31) | (imm_10_5 << 25) | (rs2 << 20) | (rs1 << 15) | (info['funct3'] << 12) | (imm_4_1 << 8) | (imm_11 << 7) | info['opcode']
        return f"{val:08x}"

    # U-type
    elif fmt == 'U':
        check_args(tokens, 2)
        rd, imm = parse_reg(tokens[1]), parse_imm(tokens[2], info['imm_bits'], signed=False)
        val = (imm << 12) | (rd << 7) | info['opcode']
        return f"{val:08x}"

    # J-type
    elif fmt == 'J':
        check_args(tokens, 2)
        rd = parse_reg(tokens[1])
        offset = resolve_target(tokens[2], current_pc, symbol_table)

        imm = parse_imm(offset, info['imm_bits'])
        imm_20    = (imm >> 20) & 0x1
        imm_10_1  = (imm >> 1)  & 0x3FF
        imm_11    = (imm >> 11) & 0x1
        imm_19_12 = (imm >> 12) & 0xFF
        val = (imm_20 << 31) | (imm_10_1 << 21) | (imm_11 << 20) | (imm_19_12 << 12) | (rd << 7) | info['opcode']
        return f"{val:08x}"

    raise ValueError(f"Unknown format '{fmt}'")


def assemble_word(tok, symbol_table):
    """.word の値(数値 or ラベルのアドレス) -> 16進数"""
    tok = tok.strip().rstrip(',')
    if tok in symbol_table:
        val = symbol_table[tok]
    else:
        try:
            val = int(tok, 0)
        except ValueError:
            raise ValueError(f"Undefined label: '{tok}'")
    if not -(1 << 31) <= val < (1 << 32):
        raise ValueError(f".word value {val} out of 32-bit range")
    return f"{val & 0xFFFFFFFF:08x}"


def strip_comment(line):
    return re.sub(r'(#|//).*', '', line).strip()


def split_labels(line):
    """'loop: addi x1, x1, 1' -> (['loop'], 'addi x1, x1, 1')"""
    labels = []
    while True:
        m = re.match(r'^([A-Za-z_.$][\w.$]*)\s*:\s*(.*)$', line)
        if not m:
            break
        labels.append(m.group(1))
        line = m.group(2).strip()
    return labels, line


def main():
    if len(sys.argv) < 2:
        print("Usage: python tools/assembler.py <input.s> [-o output.hex]")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = "output.hex"
    if "-o" in sys.argv:
        output_file = sys.argv[sys.argv.index("-o") + 1]

    with open(input_file, "r", encoding="utf-8") as f:
        lines = f.read().splitlines()
    
    # Add startup code
    numbered = list(enumerate(lines, 1))
    has_main = any(re.match(r'^\s*main\s*:', l) for l in lines)
    if has_main and "--no-startup" not in sys.argv:
        # メモリ構成による
        STACK_TOP_LUI = 0x40

        startup_code = [
            f"lui sp, {STACK_TOP_LUI:#x}",
            "jal ra, main",
            "__halt: j __halt",
        ]
        numbered = [(0, l) for l in startup_code] + numbered

    symbol_table = {}
    items = []
    errors = []

    current_section = "text"
    text_pc = 0
    rodata_pc = 0

    # Pass 1
    current_pc = 0
    for lineno, raw in numbered:
        try:
            labels, text = split_labels(strip_comment(raw))
            current_pc = text_pc if current_section == "text" else rodata_pc
            for name in labels:
                if name in symbol_table:
                    raise ValueError(f"Duplicate label '{name}'")
                symbol_table[name] = current_pc
            if not text:
                continue

            if text.startswith('.'):
                directive = text.split()[0].lower()
                if directive == '.section':
                    parts = text.split()
                    if len(parts) > 1:
                        current_section = parts[1].lstrip('.')
                    continue

                if directive == '.word':
                    values = [v for v in re.split(r'[,\s]+', text[len('.word'):]) if v]
                    if not values:
                        raise ValueError(".word needs a value")
                    for v in values:
                        items.append((lineno, raw, f".word {v}", current_section, current_pc))
                        current_pc += 4
                    continue
                elif directive == '.equ':
                    parts = [v for v in re.split(r'[,\s]+', text[len('.equ'):]) if v]
                    if len(parts) == 2:
                        symbol_table[parts[0]] = int(parts[1], 0)
                    continue

                elif directive == '.string':
                    # ""の中身pic
                    match = re.search(r'"([^"]*)"', text)
                    if not match:
                        raise ValueError("Invalid .string format")
                    s_val = match.group(1)
                    
                    s_val = s_val.encode('utf-8').decode('unicode_escape')
                    
                    bytes_data = list(s_val.encode('utf-8')) + [0]
                    
                    while len(bytes_data) % 4 != 0:
                        bytes_data.append(0)

                    for i in range(0, len(bytes_data), 4):
                        chunk = bytes_data[i:i+4]
                        val = chunk[0] | (chunk[1] << 8) | (chunk[2] << 16) | (chunk[3] << 24)
                        
                        # .word として登録
                        items.append((lineno, raw, f".word {val}", current_section, current_pc))
                        current_pc += 4
                    continue

                elif directive in SAFE_SKIP_DIRECTIVES:
                    continue
                else:
                    # .align, 未対応定義(.byte, .string,...) -> error
                    raise ValueError(f"Unsupported directive '{directive}' (align/data sections are not supported)")

            for ins in expand_pseudo(text, symbol_table):
                items.append((lineno, raw, ins, current_section, current_pc))
                current_pc += 4
        except ValueError as e:
            errors.append((lineno, raw, e))
        finally:
            if current_section == "text":
                text_pc = current_pc
            else:
                rodata_pc = current_pc

    # Pass 2:
    def assemble_byte(tok):
        """.byte の値 -> 2桁の16進数（1バイト）"""
        tok = tok.strip().rstrip(',')
        try:
            val = int(tok, 0)
        except ValueError:
            raise ValueError(f"Invalid byte value: '{tok}'")
        if not 0 <= val <= 255:
            raise ValueError(f"Byte value {val} out of range (0..255)")
        return f"{val & 0xFF:02x}"

    hex_lines = []
    for lineno, raw, text, section, ipc in items:
        try:
            if text.startswith('.word'):
                hex_lines.append(assemble_word(text.split()[1], symbol_table))
            elif text.startswith('.byte'):
                hex_lines.append(assemble_byte(text.split()[1]))
            else:
                hex_lines.append(assemble_line(text, ipc, symbol_table))
        except ValueError as e:
            errors.append((lineno, raw, e))

    if errors:
        for lineno, raw, e in sorted(errors, key=lambda x: x[0]):
            print(f"{input_file}:{lineno or '(startup)'}: error: {e}\n    {raw.strip()}")
        sys.exit(1)

    with open(output_file, "w", encoding="utf-8") as f:
        for hex_code in hex_lines:
            f.write(hex_code + "\n")

    print(f"Successfully assembled '{input_file}' -> '{output_file}' ({len(hex_lines)} instructions)")


if __name__ == "__main__":
    main()

# asm:
# 	python ../tools/assembler.py ../tools/test.s -o ../tools/test.hex

# python assembler.py prog.s -o prog.hex                # main があれば付く
# python assembler.py prog.s -o prog.hex --no-startup   # 付けない

