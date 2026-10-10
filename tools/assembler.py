# tools/assembler.py
import argparse
import re
import sys

from asm_types import REG_MAP, OPCODES, PSEUDO_INSTRUCTIONS

NOP = "addi x0, x0, 0"

# sp 初期値: コアのメモリ構成に合わせて決める
STARTUP_STACK_LUI = 0x40

# バイト/ハーフ単位のデータは未対応
UNSUPPORTED_DATA_DIRECTIVES = {
    '.byte', '.half', '.short', '.2byte', '.4byte', '.dword', '.quad',
    '.zero', '.space', '.skip', '.fill',
}

# 読み飛ばして問題ない指令
SAFE_SKIP_DIRECTIVES = {
    '.globl', '.global', '.local', '.weak', '.file',
    '.type', '.size', '.ident', '.option', '.attribute',
}

# 文字列系指令: 末尾に NUL を付けるか
STRING_DIRECTIVES = {'.string': True, '.asciz': True, '.ascii': False}

# 文字リテラルの認識('a' '\n' ',' など)
CHAR_LIT = r"'(?:\\.|[^'\\])'"
# トークンの抽出
TOKEN_RE = re.compile(CHAR_LIT + r"|[^\s,()]+")
# ""の中身の抽出
STRING_RE = re.compile(r'"((?:[^"\\]|\\.)*)"')


def tokenize(line):
    """'lb t1, 0(a0)' -> ['lb', 't1', '0', 'a0']"""
    return TOKEN_RE.findall(line)


def has_mem_operand(line):
    """メモリアクセス判定（imm(rs1) 形式か）"""
    return '(' in re.sub(CHAR_LIT, "''", line)


def strip_comment(line):
    """ コメント（# と // 以降）の除去 """
    out = []
    i = 0
    in_str = False
    while i < len(line):
        c = line[i]
        if in_str:
            out.append(c)
            if c == '\\' and i + 1 < len(line):
                out.append(line[i + 1])
                i += 1
            elif c == '"':
                in_str = False
        elif c == '"':
            in_str = True
            out.append(c)
        elif c == "'" and re.match(CHAR_LIT, line[i:]):
            n = len(re.match(CHAR_LIT, line[i:]).group(0))
            out.append(line[i:i + n])
            i += n - 1
        elif c == '#' or line.startswith('//', i):
            break
        else:
            out.append(c)
        i += 1
    return ''.join(out).strip()


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

def parse_reg(reg_str):
    """'x1' , 'a0' -> 0~31 """
    reg_str = reg_str.strip().lower()
    if re.fullmatch(r'x\d+', reg_str) and int(reg_str[1:]) <= 31:
        return int(reg_str[1:])
    elif reg_str in REG_MAP:
        return REG_MAP[reg_str]
    else:
        raise ValueError(f"Unknown register: {reg_str}")

def parse_literal_or_int(val_str):
    """文字リテラル ('a', '\\n') や数値文字列 -> 整数 """
    val_str = str(val_str).strip()
    if re.fullmatch(CHAR_LIT, val_str):
        body = val_str[1:-1]
        if body.startswith('\\'):
            body = body.encode('latin-1', 'backslashreplace').decode('unicode_escape')
        return ord(body)
    return int(val_str, 0)

def parse_imm(imm_val_or_str, bits, signed=True):
    """即値 -> 2の補数(範囲外:error)"""
    if isinstance(imm_val_or_str, int):
        val = imm_val_or_str
    else:
        try:
            val = parse_literal_or_int(imm_val_or_str)
        except (ValueError, TypeError):
            raise ValueError(f"Invalid immediate: '{imm_val_or_str}'")

    if signed:
        lo, hi = -(1 << (bits - 1)), (1 << (bits - 1)) - 1
    else:
        lo, hi = 0, (1 << bits) - 1
    if not lo <= val <= hi:
        raise ValueError(f"Immediate {val} out of range ({lo}..{hi})")
    return val & ((1 << bits) - 1)


def resolve_target(tok, current_pc=0, symbol_table=None):
    """分岐・ジャンプ先からPC相対オフセット"""
    if symbol_table is None:
        symbol_table = {}

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

    tokens = tokenize(line)
    if not tokens:
        return [line.strip()]

    op = tokens[0].lower()
    args = tokens[1:]

    if op == 'li':
        if len(args) != 2:
            raise ValueError("'li' expects 2 operands")
        return expand_li(args[0], args[1], symbol_table)

    if op == 'la':
        if len(args) != 2:
            raise ValueError("'la' expects 2 operands")
        rd, sym = args
        return [f"auipc {rd}, %pcrel_hi({sym})", f"addi {rd}, {rd}, %pcrel_lo({sym})"]

    if op == 'jal' and len(args) == 1:
        return [f"jal ra, {args[0]}"]

    if op == 'jalr' and len(args) == 1:
        return [f"jalr ra, {args[0]}, 0"]

    if op in PSEUDO_INSTRUCTIONS:
        info = PSEUDO_INSTRUCTIONS[op]
        if len(args) != info['arg_count']:
            raise ValueError(f"'{op}' expects {info['arg_count']} operands, got {len(args)}")
        return [info['template'].format(*args)]

    return [line.strip()]


def resolve_pcrel(line, current_pc, symbol_table=None):
    """%pcrel_hi(sym) / %pcrel_lo(sym) を数値に置換"""
    if symbol_table is None:
        symbol_table = {}

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
    """基本命令1行 -> 16進数(8桁)"""
    if symbol_table is None:
        symbol_table = {}

    line = resolve_pcrel(line, current_pc, symbol_table)
    tokens = tokenize(line)
    if not tokens:
        raise ValueError("Empty instruction")
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
        if has_mem_operand(line):   # lw rd, imm(rs1) / jalr rd, imm(rs1) -> [op, rd, imm, rs1]
            rd, imm_s, rs1 = parse_reg(tokens[1]), tokens[2], parse_reg(tokens[3])
        else:                       # addi rd, rs1, imm / jalr rd, rs1, imm -> [op, rd, rs1, imm]
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
        if not has_mem_operand(line):
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

    # ebreak
    elif fmt == 'SYS':
        check_args(tokens, 0)
        return f"{info['value']:08x}"

    raise ValueError(f"Unknown format '{fmt}'")


def assemble_word(tok, symbol_table):
    """.word の値 -> 16進数(8桁)"""
    tok = tok.strip().rstrip(',')
    if tok in symbol_table:
        val = symbol_table[tok]
    else:
        try:
            val = parse_literal_or_int(tok)
        except ValueError:
            raise ValueError(f"Undefined label or invalid value: '{tok}'")
    if not -(1 << 31) <= val < (1 << 32):
        raise ValueError(f".word value {val} out of 32-bit range")
    return f"{val & 0xFFFFFFFF:08x}"


def section_kind(name):
    """'.text' -> 'text' / '.rodata', '.data', '.bss' など -> 'rodata' (データ側)"""
    name = name.split(',')[0].strip().lstrip('.')
    return 'text' if name.startswith('text') else 'rodata'


def decode_string(s):
    """\\n, \\0, \\" などのエスケープを解釈 (非ASCII文字はそのまま保持)"""
    return s.encode('latin-1', 'backslashreplace').decode('unicode_escape')


def report_errors(input_file, errors):
    for lineno, raw, e in sorted(errors, key=lambda x: x[0]):
        print(f"{input_file}:{lineno or '(startup)'}: error: {e}\n    {raw.strip()}")
    sys.exit(1)


def main():
    ap = argparse.ArgumentParser(description="RV32I(+M) assembler")
    ap.add_argument("input", help="input .s file")
    ap.add_argument("-o", "--output", default="output.hex", help="output .hex file")
    ap.add_argument("--no-startup", action="store_true", help="startup code なし")
    args = ap.parse_args()

    input_file = args.input
    output_file = args.output

    with open(input_file, "r", encoding="utf-8") as f:
        lines = f.read().splitlines()

    numbered = list(enumerate(lines, 1))

    # mainあるときだけ挿入
    has_main = any(re.match(r'^\s*main\s*:', l) for l in lines)
    if has_main and not args.no_startup:
        startup_code = [
            f"lui sp, {STARTUP_STACK_LUI:#x}",
            "jal ra, main",
            "ebreak",
        ]
        numbered = [(0, l) for l in startup_code] + numbered

    symbol_table = {}
    errors = []

    # セクション管理
    #   命令/データ : (lineno, raw, text)
    #   ラベル定義  : ('LABEL_DEF', lineno, raw, name)
    #   アラインメント: ('ALIGN', lineno, raw, nbytes)
    text_items = []
    rodata_items = []
    current_section = "text"

    def target_list():
        return text_items if current_section == "text" else rodata_items

    def emit(item_text, lineno, raw):
        target_list().append((lineno, raw, item_text))

    # Pass 1-1:セクションに分類
    for lineno, raw in numbered:
        try:
            labels, text = split_labels(strip_comment(raw))

            for name in labels:
                target_list().append(('LABEL_DEF', lineno, raw, name))
            if not text:
                continue

            if text.startswith('.'):
                toks = tokenize(text)
                directive = toks[0].lower()
                dargs = toks[1:]

                if directive == '.section':
                    if dargs:
                        current_section = section_kind(dargs[0])
                    continue

                elif directive in ('.text', '.data', '.rodata', '.bss'):
                    current_section = section_kind(directive)
                    continue

                elif directive in ('.equ', '.set'):
                    if len(dargs) != 2:
                        raise ValueError(f"'{directive}' expects NAME, VALUE")
                    symbol_table[dargs[0]] = parse_literal_or_int(dargs[1])
                    continue

                elif directive == '.word':
                    if not dargs:
                        raise ValueError(".word needs a value")
                    for v in dargs:
                        emit(f".word {v}", lineno, raw)
                    continue

                elif directive in STRING_DIRECTIVES:
                    literals = STRING_RE.findall(text)
                    if not literals:
                        raise ValueError(f"Invalid {directive} format")
                    data = bytearray()
                    for lit in literals:
                        data += decode_string(lit).encode('utf-8')
                        if STRING_DIRECTIVES[directive]:
                            data.append(0)
                    while len(data) % 4:
                        data.append(0)
                    for i in range(0, len(data), 4):
                        val = int.from_bytes(data[i:i + 4], 'little')
                        emit(f".word {val}", lineno, raw)
                    continue

                elif directive in ('.align', '.p2align', '.balign'):
                    if len(dargs) < 1:
                        raise ValueError(f"'{directive}' expects an argument")
                    n = parse_literal_or_int(dargs[0])
                    nbytes = n if directive == '.balign' else (1 << n)
                    if nbytes <= 0 or nbytes & (nbytes - 1):
                        raise ValueError(f"Invalid alignment: {n}")
                    if nbytes > 4:   # 4 以下は常に真
                        target_list().append(('ALIGN', lineno, raw, nbytes))
                    continue

                elif directive in UNSUPPORTED_DATA_DIRECTIVES:
                    raise ValueError(f"'{directive}' is not supported (word-sized data only)")

                elif directive in SAFE_SKIP_DIRECTIVES:
                    continue

                else:
                    raise ValueError(f"Unsupported directive '{directive}'")

            # 通常命令・疑似命令の展開
            for ins in expand_pseudo(text, symbol_table):
                emit(ins, lineno, raw)

        except ValueError as e:
            errors.append((lineno, raw, e))

    if errors:
        report_errors(input_file, errors)

    # Pass 1-2: 連結・アドレス割り当て
    def assign(src_items, start_pc, section):
        out, pc = [], start_pc
        for item in src_items:
            if item[0] == 'LABEL_DEF':
                _, lineno, raw, name = item
                if name in symbol_table:
                    errors.append((lineno, raw, ValueError(f"Duplicate label '{name}'")))
                symbol_table[name] = pc
            elif item[0] == 'ALIGN':
                _, lineno, raw, nbytes = item
                while pc % nbytes:
                    pad = NOP if section == "text" else ".word 0"
                    out.append((lineno, raw, pad, section, pc))
                    pc += 4
            else:
                lineno, raw, text = item
                out.append((lineno, raw, text, section, pc))
                pc += 4
        return out, pc

    final_text_items, text_end = assign(text_items, 0, "text")
    final_rodata_items, _ = assign(rodata_items, text_end, "rodata")
    items = final_text_items + final_rodata_items

    if errors:
        report_errors(input_file, errors)

    # Pass 2:
    hex_lines = []
    for lineno, raw, text, section, ipc in items:
        try:
            if text.startswith('.word'):
                hex_lines.append(assemble_word(text[len('.word'):], symbol_table))
            else:
                hex_lines.append(assemble_line(text, ipc, symbol_table))
        except ValueError as e:
            errors.append((lineno, raw, e))

    if errors:
        report_errors(input_file, errors)

    with open(output_file, "w", encoding="utf-8") as f:
        for hex_code in hex_lines:
            f.write(hex_code + "\n")

    print(f"Successfully assembled '{input_file}' -> '{output_file}' "
          f"({len(hex_lines)} words: text {len(final_text_items)}, rodata {len(final_rodata_items)})")


if __name__ == "__main__":
    main()

# asm:
# 	python ../tools/assembler.py ../tools/test.s -o ../tools/test.hex

# python assembler.py prog.s -o prog.hex                # main があれば付く
# python assembler.py prog.s -o prog.hex --no-startup   # 付けない
