# RaySC-V

**A Custom RV32IM Processor with Hardware-Accelerated Ray Tracing**

専用ドメイン言語 RayQ コンパイラと，独自命令拡張および専用アクセラレータを備えた RV32IM コアの HW/SW 協調設計．

## 概要と目的

ベースラインとなる RV32I から段階的にプロセッサ・専用回路を拡張し，コンパイラ最適化との組み合わせ(計 20~24 構成)による実行性能・回路規模(LUT/DSP)・動作周波数のトレードオフを定量評価する．

すべての評価構成において，出力される PPM 画像が C 言語リファレンスとバイト単位で完全一致することを正当性の検証基準とする．

### 評価マトリクス

| HW 構成 | 内容 |
| --- | --- |
| **H0** | 単一サイクル RV32IM |
| **H1** | 単一サイクル + `custom-0`(固定小数点演算器) |
| **H2** | 5段パイプライン RV32IM |
| **H3** | 5段パイプライン + `custom-0` |
| **H4** | 5段パイプライン + `custom-0` + 球交差判定アクセラレータ |

* **コンパイラ最適化階層**:
* `-O0`: 静的スタックスロット割り当て(ベースライン)
* `-O1`: 全関数インライン展開 + 定数畳み込み / 伝播 + 死活コード削除
* `-O2`: 線形スキャンによるレジスタ割り当て(`s0`–`s11`, `t0`–`t6`)
* `-O3`: 命令スケジューリング(ロードハザード回避)+ 局所 CSE + 強度削減



---

## アーキテクチャ・システム仕様

* **専用言語 RayQ (`.rq`)**:
* 仕様は [`docs/RayQ-language-v1.0.md`](docs/RayQ-language-v1.0.md)．
* 静的型付け(`bool`, `i32`, `q16` [Q16.16 固定小数点], `vec3`, 構造体, 固定長配列)．
* メモリ安全設計のため，ポインタ・動的確保・再帰呼び出し・可変グローバル変数を排除．
* 算術系は [`ref/qmath.h`](ref/qmath.h) の C リファレンスとビット単位で完全互換．


* **メモリマップ**:
* **内部 BRAM**: `0x0000_0000` – `0x0003_FFFF`(256 KiB，命令・データ・スタック共用)．
* リセットベクタ: `0x0000_0000` / 初期スタックポインタ: `0x0004_0000`．


* **MMIO アドレスマップ**:
* `0x1000_0000`: UART TX(`sb`)
* `0x2000_0000`: サイクルカウンタ下位 32bit(`lw`，内部 64bit)
* `0x3000_0000`: 交差判定アクセラレータ制御レジスタ群


* **独自拡張命令 `custom-0**` (R-type, opcode: `0x0B`):
* `qmul` (`funct3=0x0`), `qsqrt` (`0x2`), `qrsqrt` (`0x3`), `qrcp` (`0x4`)


* **実行制御・停止**:
* 終了時は `ebreak` を実行．テストベンチはこれを検知してシミュレーションを終了し，実行サイクル数および命令数を表示．`ebreak` 自体は `instret` に含めない．


* **アライメント規約**:
* 非整列メモリアクセスは非サポート．RayQ コンパイラが全変数を 4 バイト境界に配置するため，実行時にアライメント違反は発生しない．


* **呼出規約 (ABI)**:
* 引数は 32bit ワードに平坦化し，先頭 8 ワードを `a0`–`a7`，超過分をスタック渡し．戻り値は最大 8 ワード(詳細は仕様書 §7)．



---

## ディレクトリ構成

```text
raysc-v/
├── Makefile               # ビルド・シミュレーション自動化
├── bsp/                   # スタートアップ・リンカスクリプト
│   ├── common/crt0.S      # C 言語用スタートアップ
│   └── qemu/linker.ld     # QEMU virt 用リンカスクリプト
├── compiler/              # OCaml 製 RayQ コンパイラ rayqc (.rq -> RV32IM .s)
├── hw/
│   ├── rtl/               # 合成可能 SystemVerilog コア・アクセラレータ
│   ├── tb/                # テストベンチ (tb_cpu.sv ほか)
│   └── fpga/              # 制約ファイル (XDC)，Vivado 自動化スクリプト
├── programs/              # ベンチマークコード (raytracer, mandelbrot)
├── ref/                   # 正解データ生成用 C リファレンス (qmath.h, main.c)
├── tests/
│   ├── hex/, asm/         # アセンブリ・バイナリ単体テスト
│   ├── check/             # QEMU と 自作 RTL の一致検証用スイート
│   └── golden/            # 正解出力データ (.out, .ppm)
├── tools/                 # アセンブラ (assembler.py), ログ解析スクリプト群
└── docs/                  # 言語仕様書・ハードウェア設計メモ

```

---

## ビルドと実行

```sh
# 1. 動作環境・ツールのビルド
make compiler                      # RayQ コンパイラ (rayqc) のビルド
make ref                           # C リファレンスによる golden PPM 生成

# 2. 単体・導通テスト
make smoke                         # 基本命令・cycles MMIO の最小回帰テスト
make test                          # RTL 単体テストベンチの実行
make check                         # tests/check/ 内全件の QEMU / 自作コア出力一致検証

# 3. プログラムの実行
make run SRC=programs/mandelbrot/mandelbrot.rq  # 自作 RTL コア (iverilog) で実行
make qemu SRC=programs/mandelbrot/mandelbrot.rq # QEMU virt 上で実行

```

* **コンパイル・実行オプション**:
* 最適化・拡張の指定: `make run SRC=... RAYQ_FLAGS="-O2 --accel=math"`
* QEMU は `custom-0` に非対応のため，QEMU 突き合わせ(`make check`)時は `--accel=off`(デフォルト)を使用．


* **テストベンチ実行時オプション (`tb_cpu.sv`)**:
* `+hex=<FILE>`: 実行プログラム
* `+maxcycles=<N>`: タイムアウト上限
* `+retire_trace=<FILE>`: 命令リタイアログ出力(命令追跡・差分検証用)



---

## 検証と開発規約

1. **Golden 基準の遵守**:
算術仕様および ABI を改定する場合は，`ref/qmath.h`，コンパイラ，RTL の全層を同時に更新し，単体テストをパスさせる．
2. **最適化の透過性**:
コンパイラ最適化は，算術結果，UART 文字列出力順序，MMIO アクセス順序を変更してはならない．
3. **回路テストの網羅性**:
`riscv-tests`(`rv32ui-p-*`, `rv32um-p-*`，ただし `ma_data` を除く)の全件パスをハードウェアのベースライン要件とする．

## 開発環境

* **シミュレータ / ツールチェーン**: Icarus Verilog (`iverilog`), `qemu-system-riscv32`, `riscv64-unknown-elf-gcc`, Python 3.10+, OCaml 4.14+
* **FPGA 開発環境**: AMD Vivado (ターゲット: Digilent Nexys A7-100T / Artix-7 100T)
* ※開発環境全体は付属の `Dockerfile` および `docker-compose.yml` でコンテナとして再現可能．
