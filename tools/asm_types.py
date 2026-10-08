# # tools/asm_types.py

# REG_MAP = {
#     'zero': 0,
#     'ra': 1,
#     'sp': 2,
#     'gp': 3,
#     'tp': 4,
#     't0': 5,
#     't1': 6,
#     't2': 7,
#     's0': 8,
#     'fp': 8,
#     's1': 9,
#     'a0': 10,
#     'a1': 11,
#     'a2': 12,
#     'a3': 13,
#     'a4': 14,
#     'a5': 15,
#     'a6': 16,
#     'a7': 17,
#     's2': 18,
#     's3': 19,
#     's4': 20,
#     's5': 21,
#     's6': 22,
#     's7': 23,
#     's8': 24,
#     's9': 25,
#     's10': 26,
#     's11': 27,
#     't3': 28,
#     't4': 29,
#     't5': 30,
#     't6': 31
# }

# OPCODES = {
#     # R-type
#     'add':  {'type': 'R', 'opcode': 0x33, 'funct3': 0x0, 'funct7': 0x00},
#     'sub':  {'type': 'R', 'opcode': 0x33, 'funct3': 0x0, 'funct7': 0x20},
#     'xor':  {'type': 'R', 'opcode': 0x33, 'funct3': 0x4, 'funct7': 0x00},
#     'or':   {'type': 'R', 'opcode': 0x33, 'funct3': 0x6, 'funct7': 0x00},
#     'and':  {'type': 'R', 'opcode': 0x33, 'funct3': 0x7, 'funct7': 0x00},
#     'sll':  {'type': 'R', 'opcode': 0x33, 'funct3': 0x1, 'funct7': 0x00},
#     'srl':  {'type': 'R', 'opcode': 0x33, 'funct3': 0x5, 'funct7': 0x00},
#     'sra':  {'type': 'R', 'opcode': 0x33, 'funct3': 0x5, 'funct7': 0x20},
#     'slt':  {'type': 'R', 'opcode': 0x33, 'funct3': 0x2, 'funct7': 0x00},
#     'sltu': {'type': 'R', 'opcode': 0x33, 'funct3': 0x3, 'funct7': 0x00},
#     'mul':  {'type': 'R', 'opcode': 0x33, 'funct3': 0x0, 'funct7': 0x01},
#     'mulh': {'type': 'R', 'opcode': 0x33, 'funct3': 0x1, 'funct7': 0x01},
#     'mulhsu': {'type': 'R', 'opcode': 0x33, 'funct3': 0x2, 'funct7': 0x01},
#     'mulu': {'type': 'R', 'opcode': 0x33, 'funct3': 0x3, 'funct7': 0x01},
#     'div':  {'type': 'R', 'opcode': 0x33, 'funct3': 0x4, 'funct7': 0x01},
#     'divu': {'type': 'R', 'opcode': 0x33, 'funct3': 0x5, 'funct7': 0x01},
#     'rem':  {'type': 'R', 'opcode': 0x33, 'funct3': 0x6, 'funct7': 0x01},
#     'remu': {'type': 'R', 'opcode': 0x33, 'funct3': 0x7, 'funct7': 0x01},

#     # I-type
#     'addi':  {'type': 'I', 'opcode': 0x13, 'funct3': 0x0, 'imm_bits': 12},
#     'xori':  {'type': 'I', 'opcode': 0x13, 'funct3': 0x4, 'imm_bits': 12},
#     'ori':   {'type': 'I', 'opcode': 0x13, 'funct3': 0x6, 'imm_bits': 12},
#     'andi':  {'type': 'I', 'opcode': 0x13, 'funct3': 0x7, 'imm_bits': 12},
#     'slli':  {'type': 'I', 'opcode': 0x13, 'funct3': 0x1, 'imm_bits': 5, 'funct7': 0x00},
#     'srli':  {'type': 'I', 'opcode': 0x13, 'funct3': 0x5, 'imm_bits': 5, 'funct7': 0x00},
#     'srai':  {'type': 'I', 'opcode': 0x13, 'funct3': 0x5, 'imm_bits': 5, 'funct7': 0x20},
#     'slti':  {'type': 'I', 'opcode': 0x13, 'funct3': 0x2, 'imm_bits': 12},
#     'sltiu': {'type': 'I', 'opcode': 0x13, 'funct3': 0x3, 'imm_bits': 12},
#     'lb':    {'type': 'I', 'opcode': 0x03, 'funct3': 0x0, 'imm_bits': 12},
#     'lh':    {'type': 'I', 'opcode': 0x03, 'funct3': 0x1, 'imm_bits': 12},
#     'lw':    {'type': 'I', 'opcode': 0x03, 'funct3': 0x2, 'imm_bits': 12},
#     'lbu':   {'type': 'I', 'opcode': 0x03, 'funct3': 0x4, 'imm_bits': 12},
#     'lhu':   {'type': 'I', 'opcode': 0x03, 'funct3': 0x5, 'imm_bits': 12},
#     'jalr':  {'type': 'I', 'opcode': 0x67, 'funct3': 0x0, 'imm_bits': 12},

#     # S-type
#     'sb':    {'type': 'S', 'opcode': 0x23, 'funct3': 0x0, 'imm_bits': 12},
#     'sh':    {'type': 'S', 'opcode': 0x23, 'funct3': 0x1, 'imm_bits': 12},
#     'sw':    {'type': 'S', 'opcode': 0x23, 'funct3': 0x2, 'imm_bits': 12},

#     # B-type
#     'beq':   {'type': 'B', 'opcode': 0x63, 'funct3': 0x0, 'imm_bits': 13},
#     'bne':   {'type': 'B', 'opcode': 0x63, 'funct3': 0x1, 'imm_bits': 13},
#     'blt':   {'type': 'B', 'opcode': 0x63, 'funct3': 0x4, 'imm_bits': 13},
#     'bge':   {'type': 'B', 'opcode': 0x63, 'funct3': 0x5, 'imm_bits': 13},
#     'bltu':  {'type': 'B', 'opcode': 0x63, 'funct3': 0x6, 'imm_bits': 13},
#     'bgeu':  {'type': 'B', 'opcode': 0x63, 'funct3': 0x7, 'imm_bits': 13},

#     # U-type
#     'lui':   {'type': 'U', 'opcode': 0x37, 'imm_bits': 20},
#     'auipc': {'type': 'U', 'opcode': 0x17, 'imm_bits': 20},

#     # J-type
#     'jal':   {'type': 'J', 'opcode': 0x6f, 'imm_bits': 21},
# }

# PSEUDO_INSTRUCTIONS = {
#     'nop':  {'arg_count': 0, 'template': "addi x0, x0, 0"},
#     'mv':   {'arg_count': 2, 'template': "addi {0}, {1}, 0"},
#     'not':  {'arg_count': 2, 'template': "xori {0}, {1}, -1"},
#     'neg':  {'arg_count': 2, 'template': "sub {0}, x0, {1}"},
#     'j':    {'arg_count': 1, 'template': "jal x0, {0}"},
#     'jr':   {'arg_count': 1, 'template': "jalr x0, {0}, 0"},
#     'ret':  {'arg_count': 0, 'template': "jalr x0, ra, 0"},
#     'beqz': {'arg_count': 2, 'template': "beq {0}, x0, {1}"},
#     'bnez': {'arg_count': 2, 'template': "bne {0}, x0, {1}"},
#     'bgez': {'arg_count': 2, 'template': "bge {0}, x0, {1}"},
#     'blez': {'arg_count': 2, 'template': "ble {0}, x0, {1}"},
#     'bltz': {'arg_count': 2, 'template': "blt {0}, x0, {1}"},
#     'bgtz': {'arg_count': 2, 'template': "bgt {0}, x0, {1}"},
#     'call': {'arg_count': 1, 'template': "jal ra, {0}"},
# }

# tools/asm_types.py

REG_MAP = {
    'zero': 0,
    'ra': 1,
    'sp': 2,
    'gp': 3,
    'tp': 4,
    't0': 5,
    't1': 6,
    't2': 7,
    's0': 8,
    'fp': 8,
    's1': 9,
    'a0': 10,
    'a1': 11,
    'a2': 12,
    'a3': 13,
    'a4': 14,
    'a5': 15,
    'a6': 16,
    'a7': 17,
    's2': 18,
    's3': 19,
    's4': 20,
    's5': 21,
    's6': 22,
    's7': 23,
    's8': 24,
    's9': 25,
    's10': 26,
    's11': 27,
    't3': 28,
    't4': 29,
    't5': 30,
    't6': 31,
}

OPCODES = {
    # R-type
    'add':    {'type': 'R', 'opcode': 0x33, 'funct3': 0x0, 'funct7': 0x00},
    'sub':    {'type': 'R', 'opcode': 0x33, 'funct3': 0x0, 'funct7': 0x20},
    'xor':    {'type': 'R', 'opcode': 0x33, 'funct3': 0x4, 'funct7': 0x00},
    'or':     {'type': 'R', 'opcode': 0x33, 'funct3': 0x6, 'funct7': 0x00},
    'and':    {'type': 'R', 'opcode': 0x33, 'funct3': 0x7, 'funct7': 0x00},
    'sll':    {'type': 'R', 'opcode': 0x33, 'funct3': 0x1, 'funct7': 0x00},
    'srl':    {'type': 'R', 'opcode': 0x33, 'funct3': 0x5, 'funct7': 0x00},
    'sra':    {'type': 'R', 'opcode': 0x33, 'funct3': 0x5, 'funct7': 0x20},
    'slt':    {'type': 'R', 'opcode': 0x33, 'funct3': 0x2, 'funct7': 0x00},
    'sltu':   {'type': 'R', 'opcode': 0x33, 'funct3': 0x3, 'funct7': 0x00},
    # RV32M ('mulu' は存在しない。上位ビット符号なし乗算は mulhu)
    'mul':    {'type': 'R', 'opcode': 0x33, 'funct3': 0x0, 'funct7': 0x01},
    'mulh':   {'type': 'R', 'opcode': 0x33, 'funct3': 0x1, 'funct7': 0x01},
    'mulhsu': {'type': 'R', 'opcode': 0x33, 'funct3': 0x2, 'funct7': 0x01},
    'mulhu':  {'type': 'R', 'opcode': 0x33, 'funct3': 0x3, 'funct7': 0x01},
    'div':    {'type': 'R', 'opcode': 0x33, 'funct3': 0x4, 'funct7': 0x01},
    'divu':   {'type': 'R', 'opcode': 0x33, 'funct3': 0x5, 'funct7': 0x01},
    'rem':    {'type': 'R', 'opcode': 0x33, 'funct3': 0x6, 'funct7': 0x01},
    'remu':   {'type': 'R', 'opcode': 0x33, 'funct3': 0x7, 'funct7': 0x01},

    # I-type
    'addi':  {'type': 'I', 'opcode': 0x13, 'funct3': 0x0, 'imm_bits': 12},
    'xori':  {'type': 'I', 'opcode': 0x13, 'funct3': 0x4, 'imm_bits': 12},
    'ori':   {'type': 'I', 'opcode': 0x13, 'funct3': 0x6, 'imm_bits': 12},
    'andi':  {'type': 'I', 'opcode': 0x13, 'funct3': 0x7, 'imm_bits': 12},
    'slli':  {'type': 'I', 'opcode': 0x13, 'funct3': 0x1, 'imm_bits': 5, 'funct7': 0x00},
    'srli':  {'type': 'I', 'opcode': 0x13, 'funct3': 0x5, 'imm_bits': 5, 'funct7': 0x00},
    'srai':  {'type': 'I', 'opcode': 0x13, 'funct3': 0x5, 'imm_bits': 5, 'funct7': 0x20},
    'slti':  {'type': 'I', 'opcode': 0x13, 'funct3': 0x2, 'imm_bits': 12},
    'sltiu': {'type': 'I', 'opcode': 0x13, 'funct3': 0x3, 'imm_bits': 12},
    'lb':    {'type': 'I', 'opcode': 0x03, 'funct3': 0x0, 'imm_bits': 12},
    'lh':    {'type': 'I', 'opcode': 0x03, 'funct3': 0x1, 'imm_bits': 12},
    'lw':    {'type': 'I', 'opcode': 0x03, 'funct3': 0x2, 'imm_bits': 12},
    'lbu':   {'type': 'I', 'opcode': 0x03, 'funct3': 0x4, 'imm_bits': 12},
    'lhu':   {'type': 'I', 'opcode': 0x03, 'funct3': 0x5, 'imm_bits': 12},
    'jalr':  {'type': 'I', 'opcode': 0x67, 'funct3': 0x0, 'imm_bits': 12},

    # S-type
    'sb':    {'type': 'S', 'opcode': 0x23, 'funct3': 0x0, 'imm_bits': 12},
    'sh':    {'type': 'S', 'opcode': 0x23, 'funct3': 0x1, 'imm_bits': 12},
    'sw':    {'type': 'S', 'opcode': 0x23, 'funct3': 0x2, 'imm_bits': 12},

    # B-type
    'beq':   {'type': 'B', 'opcode': 0x63, 'funct3': 0x0, 'imm_bits': 13},
    'bne':   {'type': 'B', 'opcode': 0x63, 'funct3': 0x1, 'imm_bits': 13},
    'blt':   {'type': 'B', 'opcode': 0x63, 'funct3': 0x4, 'imm_bits': 13},
    'bge':   {'type': 'B', 'opcode': 0x63, 'funct3': 0x5, 'imm_bits': 13},
    'bltu':  {'type': 'B', 'opcode': 0x63, 'funct3': 0x6, 'imm_bits': 13},
    'bgeu':  {'type': 'B', 'opcode': 0x63, 'funct3': 0x7, 'imm_bits': 13},

    # U-type
    'lui':   {'type': 'U', 'opcode': 0x37, 'imm_bits': 20},
    'auipc': {'type': 'U', 'opcode': 0x17, 'imm_bits': 20},

    # J-type
    'jal':   {'type': 'J', 'opcode': 0x6f, 'imm_bits': 21},
}

# 1命令に展開される疑似命令 (li / la / 引数1個の jal, jalr は assembler.py 側で処理)
PSEUDO_INSTRUCTIONS = {
    'nop':  {'arg_count': 0, 'template': "addi x0, x0, 0"},
    'mv':   {'arg_count': 2, 'template': "addi {0}, {1}, 0"},
    'not':  {'arg_count': 2, 'template': "xori {0}, {1}, -1"},
    'neg':  {'arg_count': 2, 'template': "sub {0}, x0, {1}"},
    'seqz': {'arg_count': 2, 'template': "sltiu {0}, {1}, 1"},
    'snez': {'arg_count': 2, 'template': "sltu {0}, x0, {1}"},
    'sltz': {'arg_count': 2, 'template': "slt {0}, {1}, x0"},
    'sgtz': {'arg_count': 2, 'template': "slt {0}, x0, {1}"},

    'j':    {'arg_count': 1, 'template': "jal x0, {0}"},
    'jr':   {'arg_count': 1, 'template': "jalr x0, {0}, 0"},
    'ret':  {'arg_count': 0, 'template': "jalr x0, ra, 0"},
    'call': {'arg_count': 1, 'template': "jal ra, {0}"},
    'tail': {'arg_count': 1, 'template': "jal x0, {0}"},

    'beqz': {'arg_count': 2, 'template': "beq {0}, x0, {1}"},
    'bnez': {'arg_count': 2, 'template': "bne {0}, x0, {1}"},
    'bgez': {'arg_count': 2, 'template': "bge {0}, x0, {1}"},
    'bltz': {'arg_count': 2, 'template': "blt {0}, x0, {1}"},
    'blez': {'arg_count': 2, 'template': "bge x0, {0}, {1}"},   # 以前は存在しない 'ble' を指していた
    'bgtz': {'arg_count': 2, 'template': "blt x0, {0}, {1}"},   # 以前は存在しない 'bgt' を指していた

    # オペランド入れ替え系
    'bgt':  {'arg_count': 3, 'template': "blt {1}, {0}, {2}"},
    'ble':  {'arg_count': 3, 'template': "bge {1}, {0}, {2}"},
    'bgtu': {'arg_count': 3, 'template': "bltu {1}, {0}, {2}"},
    'bleu': {'arg_count': 3, 'template': "bgeu {1}, {0}, {2}"},
}