# RaySC-V

A Custom RV32IM Processor with Hardware-Accelerated Ray Tracing.

独自命令拡張および専用アクセラレータを備えた RV32IM コアと，専用言語 RayQ のコンパイラの協調設計．

## プロジェクトの目標

汎用的な RV32I を段階的に拡張し，コンパイラと自作プロセッサ・アクセラレータの協調設計による高速化を定量的に評価する．

| 段階 | 内容 |
| --- | --- |
| 1. RV32I | ベースライン |
| 2. RV32IM | 乗除算の実装（単一サイクル乗算器，マルチサイクル除算器） |
| 3. 独自命令 `custom-0` | `qmul` / `qsqrt` / `qrsqrt` / `qrcp`（Q16.16 固定小数点演算） |
| 4. 5 段パイプライン | RV32IM のパイプライン化（同期 BRAM に対応） |
| 5. 交差判定アクセラレータ | 光線とシーン（球の配列）の交差判定を行うコプロセッサ |

コンパイラ側も段階的に最適化する（`-O0` スタックスロット方式 → `-O1` 全関数インライン + 定数畳み込み → `-O2` レジスタ割り当て → `-O3` スケジューリングなど）．

**評価**は，HW 構成 × コンパイラ最適化の組み合わせ（約 24 通り）で，命令数・サイクル数・LUT・DSP・動作周波数・実行時間を測り，速さと回路規模のトレードオフを見る．**すべての構成で，出力される PPM 画像が C リファレンス（golden）と 1 バイトも違わない**ことを正しさの条件とする．

| HW 構成 | 内容 |
| --- | --- |
| H0 | 単一サイクル RV32IM |
| H1 | 単一サイクル + `custom-0` |
| H2 | 5 段パイプライン RV32IM |
| H3 | 5 段パイプライン + `custom-0` |
| H4 | 5 段パイプライン + `custom-0` + 交差判定アクセラレータ |

## 仕様上の決定事項

- **言語**: RayQ（`.rq`）．仕様は [`docs/RayQ-language-v1.0.md`](docs/RayQ-language-v1.0.md)．型は `bool` / `i32` / `q16`（Q16.16）/ `vec3`，構造体，固定長配列．ポインタ・ヒープ・再帰・可変グローバルはない．算術はビット完全に定義され，C リファレンス [`ref/qmath.h`](ref/qmath.h) と一致する．
- **メモリ**: BRAM `0x0000_0000` - `0x0003_FFFF`（256 KB，コード・定数・スタックの共用）．リセット PC は `0x0000_0000`，初期 `sp` は `0x0004_0000`（末尾，下方伸長）．
- **MMIO**
  - UART 送信: `0x1000_0000`（`sb`）
  - サイクルカウンタ（下位 32bit）: `0x2000_0000`（`lw`）．内部は 64bit で，最終値はテストベンチが読む
  - 交差判定アクセラレータ: `0x3000_0000`（予約．インターフェースは仕様策定中）
- **独自命令**: `custom-0`（opcode `0x0B`，R-type）．`qmul`（funct3=0），`qsqrt`（2），`qrsqrt`（3），`qrcp`（4）．
- **停止**: `ebreak`．`main` から戻ると `ebreak` を実行して停止する．`ebreak` は `instret` に数えない．
- **非整列アクセスは非対応**（riscv-tests の `ma_data` は対象外）．RayQ のすべての型は 4 バイトの倍数で 4 バイト境界に置かれるので，コンパイラの出力では起きない．バイトアクセス（`lbu` / `sb`）は UART と文字列にだけ使う．
- **ABI**: 引数を 32bit ワードに平坦化し，先頭 8 ワードを `a0`-`a7`，残りをスタックに渡す．戻り値は 8 ワードまで．詳細は仕様書の §7．

## ディレクトリ構成

```
raysc-v/
├── Makefile              # チームの入り口 (make help)
├── README.md
├── bsp/                  # ベアメタル実行基盤
│   ├── common/crt0.S     #   C プログラム用の起動コード
│   ├── qemu/linker.ld    #   QEMU virt 用
│   └── hardware/linker.ld#   自作コア用
├── compiler/             # OCaml 製 RayQ コンパイラ rayqc (.rq -> RV32IM アセンブリ)
├── hw/
│   ├── rtl/              #   合成可能な SystemVerilog のみ
│   ├── tb/               #   テストベンチ (tb_cpu.sv ほか)
│   └── fpga/             #   XDC，Vivado スクリプト
├── programs/             # コンパイル・ベンチマーク対象のプログラム (raytracer, mandelbrot ...)
├── ref/                  # 信頼できるリファレンス
│   ├── qmath.h           #   ビット完全な算術 (正解)
│   └── main.c            #   固定小数点 C 版レイトレーサー (golden PPM を作る)
├── tests/
│   ├── hex/              #   手書き hex の最小テスト (smoke)
│   ├── asm/              #   手書きアセンブリの fixture
│   ├── check/            #   QEMU と RTL の出力を突き合わせるテスト (.rq / .s / .c)
│   ├── golden/           #   期待出力 (<名前>.out)
│   └── fixtures/         #   小さな入力データ
├── tools/                # assembler.py, bin2hex.py, trace_report.py など
├── docs/                 # 言語仕様，設計メモ
└── build/                # 生成物のみ (gitignore)．ソースツリーを鏡写しにする
```

`build/` はソースツリーを鏡写しにする．例: `tests/check/foo.rq` → `build/tests/check/foo.s`，`foo.hex`，`foo.qemu.out`，`foo.rtl.out`．

## 使い方

```sh
make help                          # ターゲットの一覧
make smoke                         # 自作コアの最小動作確認（これが通れば CPU は動いている）
make run SRC=tests/asm/hello.s     # 自作コア (iverilog) で実行．.rq / .c / .s / .hex が使える
make qemu SRC=programs/xxx/main.c  # QEMU で実行
make check                         # tests/check/ 全件で QEMU の出力 == RTL の出力
make test                          # RTL 単体テスト (hw/tb/tb_*.sv)
make compiler                      # rayqc をビルド
make ref                           # C リファレンスを実行して golden.ppm を作る
```

- `RAYQ_FLAGS="-O2 --accel=math"` でコンパイラの最適化レベルとアクセラレータの使用を指定できる．QEMU は `custom-0` を実行できないので，`make check` は `--accel=off`（既定）で使う．
- コンパイラの呼び出し: `rayqc prog.rq [-O0..-O3] [--accel=off|math|isect] -o prog.s`．出力は `main:` と定数データだけで，起動コードは後段が付ける（自作アセンブラは `PC=0`，`sp=0x40000`，`jal main`，`ebreak`．QEMU 側は `bsp/common/crt0.S`）．
- テストベンチ `hw/tb/tb_cpu.sv` のオプション: `+hex=FILE`（必須），`+uart=FILE`，`+maxcycles=N`，`+retire_trace=FILE`，`+vcd=FILE`，`+trace`．停止時に `[HALT] kind=... pc=... cycles=... instret=...` を表示する．

## テストの種類

| 種類 | 内容 |
| --- | --- |
| `make smoke` | `tests/hex/smoke.hex`．mul/div/rem，load/store，分岐，jal/jalr，cycles MMIO を確かめ，成功すると `OK` を出力する．失敗時は `NG<文字>`（文字は項目．`smoke.s` の先頭コメント参照） |
| `make check` | 同じプログラムを QEMU と自作コアで動かし，UART 出力を `cmp` で比較する．`tests/golden/<名前>.out` があればそれとも比較する |
| `make test` | 各 RTL モジュールの単体テスト |
| riscv-tests | `rv32ui` / `rv32um` が iverilog で全パス（`ma_data` を除く） |
| 全構成の画像一致 | すべての HW × 最適化の組み合わせで，PPM が golden と同一 |

## 開発のルール

- 算術（仕様書 §3，§9）と ABI（§7）を変えるときは，`ref/qmath.h`，コンパイラ，RTL をすべて直し，全員に周知する．
- コンパイラの最適化は，算術結果・UART 出力・MMIO の実行順序を変えない（仕様書 §11）．
- RayQ 仕様の曖昧な点は，実装する前に仕様書へ書く．

## 必要なツール

`iverilog`，`python3`，`ocaml`（`ocamllex`，`ocamlyacc`），RISC-V のクロスツールチェーン（`riscv64-unknown-elf-gcc` など），`qemu-system-riscv32`，Vivado（合成・実機）．Docker 用の定義が `Dockerfile` と `docker-compose.yml` にある．

