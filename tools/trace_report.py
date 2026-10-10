#!/usr/bin/env python3
"""trace_report.py : RV32IM 実行トレースの解析ツール

入力 : 1行1命令のテキスト "PC 命令語"(16進)。retireした命令だけを出力しておくこと。
使い方:
  python3 tools/trace_report.py trace.txt
  python3 tools/trace_report.py trace.txt --cycles 12425056 --json run_a.json
  python3 tools/trace_report.py trace.txt --dis prog.dis      # objdump -d の出力
  python3 tools/trace_report.py --compare run_a.json run_b.json
"""
import argparse
import json
import re
from collections import Counter

LOADS = {'lb', 'lh', 'lw', 'lbu', 'lhu'}
STORES = {'sb', 'sh', 'sw'}
BRANCHES = {'beq', 'bne', 'blt', 'bge', 'bltu', 'bgeu'}


def sx(v, bits):
    v &= (1 << bits) - 1
    return v - (1 << bits) if v >> (bits - 1) else v


def decode(i):
    """戻り値: (mnemonic, rd, rs1, rs2, imm)  immは I形式、storeのみS形式"""
    op, f3, f7 = i & 0x7F, (i >> 12) & 7, (i >> 25) & 0x7F
    rd, rs1, rs2 = (i >> 7) & 31, (i >> 15) & 31, (i >> 20) & 31
    imm = sx(i >> 20, 12)
    if op == 0x33:
        if f7 == 1:
            m = ['mul', 'mulh', 'mulhsu', 'mulhu', 'div', 'divu', 'rem', 'remu'][f3]
        else:
            m = ['add', 'sll', 'slt', 'sltu', 'xor', 'srl', 'or', 'and'][f3]
            if f7 == 0x20:
                m = {'add': 'sub', 'srl': 'sra'}.get(m, m)
    elif op == 0x13:
        m = ['addi', 'slli', 'slti', 'sltiu', 'xori', 'srli', 'ori', 'andi'][f3]
        if f3 == 5 and (i >> 30) & 1:
            m = 'srai'
    elif op == 0x03:
        m = ['lb', 'lh', 'lw', '?', 'lbu', 'lhu', '?', '?'][f3]
    elif op == 0x23:
        m = ['sb', 'sh', 'sw', '?', '?', '?', '?', '?'][f3]
        imm = sx(((i >> 25) << 5) | ((i >> 7) & 31), 12)
    elif op == 0x63:
        m = ['beq', 'bne', '?', '?', 'blt', 'bge', 'bltu', 'bgeu'][f3]
    else:
        m = {0x6F: 'jal', 0x67: 'jalr', 0x37: 'lui', 0x17: 'auipc',
             0x0B: 'custom0', 0x2B: 'custom1', 0x73: 'system',
             0x0F: 'fence'}.get(op, 'unknown')
    return m, rd, rs1, rs2, imm


def category(m):
    if m in ('mul', 'mulh', 'mulhsu', 'mulhu'):
        return 'mul'
    if m in ('div', 'divu', 'rem', 'remu'):
        return 'div/rem'
    if m in LOADS:
        return 'load'
    if m in STORES:
        return 'store'
    if m in BRANCHES:
        return 'branch'
    if m in ('jal', 'jalr'):
        return 'jump'
    if m.startswith('custom'):
        return 'custom'
    return 'alu'


def load_trace(path):
    cnt, inst_at = Counter(), {}
    with open(path) as f:
        for line in f:
            p = line.split()
            if len(p) < 2:
                continue
            try:
                pc, inst = int(p[0], 16), int(p[1], 16)
            except ValueError:
                continue
            cnt[(pc, inst)] += 1
            inst_at[pc] = inst
    return cnt, inst_at


def load_dis(path):
    rx = re.compile(r'^\s*([0-9a-f]+):\s+[0-9a-f]+\s+(.*\S)')
    d = {}
    with open(path) as f:
        for line in f:
            m = rx.match(line)
            if m:
                d[int(m.group(1), 16)] = m.group(2).replace('\t', ' ')
    return d


def analyze(cnt, stack_regs):
    mix, cat, addi, base, over = Counter(), Counter(), Counter(), Counter(), Counter()
    for (pc, inst), n in cnt.items():
        m, rd, rs1, rs2, imm = decode(inst)
        mix[m] += n
        cat[category(m)] += n
        if m == 'addi':
            if rd == 0:
                k = 'nop'
            elif rd == 2 and rs1 == 2:
                k = 'sp調整'
            elif imm == 0:
                k = 'mv'
            elif rs1 == 0:
                k = 'li'
            elif rs1 == 2:
                k = 'spからのアドレス計算'
            else:
                k = 'その他(加算・カウンタ)'
            addi[k] += n
            if k in ('sp調整', 'mv'):
                over[k] += n
        elif m in LOADS or m in STORES:
            base['x%d' % rs1] += n
            if rs1 in stack_regs:
                over['スタックのload/store'] += n
    return mix, cat, addi, base, over


def find_blocks(cnt):
    per_pc = {pc: n for (pc, inst), n in cnt.items()}
    blocks, cur = [], None
    for pc in sorted(per_pc):
        n = per_pc[pc]
        if cur and pc == cur['end'] + 4 and n == cur['count']:
            cur['end'] = pc
        else:
            if cur:
                blocks.append(cur)
            cur = {'start': pc, 'end': pc, 'count': n}
    if cur:
        blocks.append(cur)
    for b in blocks:
        b['len'] = (b['end'] - b['start']) // 4 + 1
        b['total'] = b['len'] * b['count']
    return sorted(blocks, key=lambda b: -b['total'])


def pct(a, b):
    return 100.0 * a / b if b else 0.0


def show_table(title, counter, total, limit=None):
    print('\n--- %s' % title)
    for k, c in counter.most_common(limit):
        print('  %-26s %10d  %5.1f%%' % (k, c, pct(c, total)))


def compare(fa, fb):
    a, b = json.load(open(fa)), json.load(open(fb))
    print('%-22s %14s %14s %8s' % ('', fa, fb, 'B/A'))

    def row(name, x, y):
        r = (y / x) if x else float('nan')
        print('%-22s %14s %14s %8.3f' % (name, x, y, r))

    row('命令数', a['total'], b['total'])
    if a.get('cycles') and b.get('cycles'):
        row('サイクル数', a['cycles'], b['cycles'])
    for k in sorted(set(a['categories']) | set(b['categories'])):
        row('  ' + k, a['categories'].get(k, 0), b['categories'].get(k, 0))
    row('オーバーヘッド命令', sum(a['overhead'].values()), sum(b['overhead'].values()))


def main():
    ap = argparse.ArgumentParser(description='RV32IM 実行トレースの解析')
    ap.add_argument('trace', nargs='?')
    ap.add_argument('--cycles', type=int, help='総サイクル数(Verilatorの出力)')
    ap.add_argument('--dis', help='objdump -d の出力(ホットブロックの表示に使う)')
    ap.add_argument('--json', help='結果の保存先')
    ap.add_argument('--stack-regs', default='2', help='スタック基準とみなすレジスタ番号(例: 2,8)')
    ap.add_argument('--blocks', type=int, default=5, help='表示するホットブロック数')
    ap.add_argument('--show', type=int, default=2, help='中身を表示するブロック数')
    ap.add_argument('--compare', nargs=2, metavar=('A.json', 'B.json'))
    a = ap.parse_args()

    if a.compare:
        compare(*a.compare)
        return
    if not a.trace:
        ap.error('trace を指定してください')

    stack_regs = {int(x) for x in a.stack_regs.split(',')}
    cnt, inst_at = load_trace(a.trace)
    total = sum(cnt.values())
    mix, cat, addi, base, over = analyze(cnt, stack_regs)

    print('命令数: %d' % total)
    if a.cycles:
        extra = a.cycles - total
        print('サイクル数: %d   CPI: %.3f' % (a.cycles, a.cycles / total))
        divs = cat.get('div/rem', 0)
        if divs:
            print('  余分なサイクル %d = div/rem %d回 x 約%.1f サイクル' % (extra, divs, extra / divs))

    show_table('カテゴリ別', cat, total)
    show_table('命令別', mix, total, 20)
    show_table('addi の内訳', addi, mix.get('addi', 0))
    show_table('load/store のベースレジスタ', base, mix_ls(mix))
    ov = sum(over.values())
    show_table('データ移動オーバーヘッド(レジスタに置けば消える候補)', over, total)
    print('  合計 %d (%.1f%%)' % (ov, pct(ov, total)))

    blocks = find_blocks(cnt)
    print('\n--- ホットブロック(連続PCで実行回数が同じ区間)')
    if blocks:
        top = blocks[0]
        print('  目安: 全命令数 / 最頻ブロックの実行回数 = %.1f 命令/回' % (total / top['count']))
    dis = load_dis(a.dis) if a.dis else {}
    for idx, b in enumerate(blocks[:a.blocks]):
        print('  #%d %08x-%08x  長さ%3d  実行%9d回  計%10d (%.1f%%)'
              % (idx + 1, b['start'], b['end'], b['len'], b['count'], b['total'], pct(b['total'], total)))
        if idx < a.show:
            for pc in range(b['start'], min(b['end'], b['start'] + 4 * 79) + 4, 4):
                text = dis.get(pc)
                if text is None:
                    m, rd, rs1, rs2, imm = decode(inst_at[pc])
                    # text = '%s rd=x%d rs1=x%d rs2=x%d imm=%d' % (m, rd, rs1, rs2, imm)
                    text = '%s x%d x%d x%d %d' % (m, rd, rs1, rs2, imm)
                print('       %08x  %s' % (pc, text))

    if a.json:
        with open(a.json, 'w') as f:
            json.dump({'total': total, 'cycles': a.cycles, 'mix': mix, 'categories': cat,
                       'addi': addi, 'base': base, 'overhead': over,
                       'overhead_pct': pct(ov, total)}, f, ensure_ascii=False, indent=1)


def mix_ls(mix):
    return sum(mix[m] for m in LOADS | STORES)


if __name__ == '__main__':
    main()
