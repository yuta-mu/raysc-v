# RaySC-V HW × コンパイラ最適化 評価チェックリスト

目的:
1. **HW 機能追加のトレードオフ**（「命令・回路を足せば常に速くなる」わけではないことの実証）
2. **コンパイラ最適化 (`-O0`〜`-O3`) の効果**（LUT/DSP/$F_{\max}$ ペナルティ 0 でどれだけ削れるか）
3. **ソフト最適化 vs ハードアクセラレーションの比較**（`Cycles / Fmax` の実時間、および `Speedup / kLUT`・`Speedup / DSP`）

---

## 1. 評価対象ハードウェア構成（`hw/fpga/configs.tcl`）

| 構成名 (`hw_config`) | 役割・主張ポイント |
| --- | --- |
| `RV32I` | DSP=0・最小回路面積・ベースライン上限 $F_{\max}$ の確認用 |
| `RV32I_MulOnly` | **M拡張の内訳切り分け**: `MUL` だけ（`DIV=0`）にして LUT の大半が除算器であることを示す |
| `RV32IM_base` | 組合せ乗算器 (`PIPE_MUL=0`) による $F_{\max}$ 律速の Before 基準 |
| `RV32IM_pipemul` | 3サイクルパイプライン乗算 (`PIPE_MUL=1`) 後の標準 RV32IM 基準 |
| `RV32IM_Zbb` | **反例①**: Zbb 追加で命令数は微減するが $F_{\max}$ が低下し、限界周波数実時間が悪化し得ることを示す |
| `RV32IM_Zbb_Rand` | **コスパ最強**: `custom-0` のうち `QRAND`（約数十LUT・0 DSP・0ストール）だけの面積/$F_{\max}$/速度効果 |
| `RV32IM_Zbb_QmulSqrt` | **犯人特定**: `qrsqrt`/`qrcp` を抜いた `qmul+qsqrt` だけの $F_{\max}$ を測り、55MHz 低下の主因を切り分け |
| `RV32IM_Zbb_MathOnly` | `custom-0` 算術4種のみ（`QRAND=0`）と `Rand` の比較 |
| `RV32IM_Zbb_C0` | **反例②**: `custom-0` 全部入り（`qrsqrt` 律速で $F_{\max}$ 低下するトレードオフ） |
| `RV32IM_Zbb_C0_nostall` | `qmul` 組合せ化 (`QMUL_STALL=0`) による「50MHz 固定なら得・限界周波数なら一長一短」の比較 |
| `RV32IM_Zbb_Rand_Accel` | **アクセラレータ単体の $F_{\max}$ 検証**: `qrcp`/`qrsqrt` なしで `Accel + QRAND` のみの限界周波数と性能 |
| `RV32IM_Zbb_C0_Accel` | **本命**: DSP 192 個 (80%)・LUT 増・配線混雑による $F_{\max}$ 低下を、並列交差判定のサイクル激減で逆転 |
| `full_zerostall` | **50MHz 理論最速**: `mul` も `qmul` も完全 0 ストール（CPI 最小 vs $F_{\max}$ の直接対決） |

---

## 2. 測定ワークフロー

### Step A: ハードウェア単体の面積・限界 $F_{\max}$ 計測（すでに完了済みなら再実行不要）

```bat
hw\fpga\run_sweep.bat
```

※ `.hex`（`-O0`〜`-O3`）を変えても LUT / DSP / $F_{\max}$ は変わらないため、**RTL や XDC を変更しない限り再実行は不要** です。
※ 今後 `feat/video_sub`（VGA 出力）をマージした際は、最終 SoC 規模を確認するため以下を 1 回実行してください。

```bat
hw\fpga\run_sweep.bat search RV32IM_Zbb_C0_Accel explore
```

### Step B: `.hex` 生成（コンパイラ最適化 × アクセラレータ組合せ）

リポジトリルート（Linux / WSL 等のツールチェーン側）で各 `.hex` を生成します。

| ラベル例 | プログラム | `RAYQ_FLAGS` | 対応 HW 構成 (`hw_config`) |
| --- | --- | --- | --- |
| `O0_base` | `programs/raytracer/main.rq` | `-O0 --accel=off` | `RV32IM_pipemul` |
| `O1_base` | `programs/raytracer/main.rq` | `-O1 --accel=off` | `RV32IM_pipemul` |
| `O2_base` | `programs/raytracer/main.rq` | `-O2 --accel=off` | `RV32IM_pipemul` |
| `O3_base` | `programs/raytracer/main.rq` | `-O3 --accel=off` | `RV32IM_pipemul` |
| `O3_zbb` | `programs/raytracer/main.rq` | `-O3 --accel=off` (Zbb有効版) | `RV32IM_Zbb` |
| `O0_math` | `programs/raytracer/main.rq` | `-O0 --accel=math` | `RV32IM_Zbb_C0` |
| `O1_math` | `programs/raytracer/main.rq` | `-O1 --accel=math` | `RV32IM_Zbb_C0` |
| `O2_math` | `programs/raytracer/main.rq` | `-O2 --accel=math` | `RV32IM_Zbb_C0` |
| `O3_math` | `programs/raytracer/main.rq` | `-O3 --accel=math` | `RV32IM_Zbb_C0` |
| `O0_isect` | `programs/raytracer/main_ar.rq` | `-O0 --accel=isect` | `RV32IM_Zbb_C0_Accel` |
| `O1_isect` | `programs/raytracer/main_ar.rq` | `-O1 --accel=isect` | `RV32IM_Zbb_C0_Accel` |
| `O2_isect` | `programs/raytracer/main_ar.rq` | `-O2 --accel=isect` | `RV32IM_Zbb_C0_Accel` |
| `O3_isect` | `programs/raytracer/main_ar.rq` | `-O3 --accel=isect` | `RV32IM_Zbb_C0_Accel` |

※ `--accel=off` / `math` / `isect` や `main_ar.rq` / `main_ir.rq`（乱数あり版）など、手元で定義している構成名に合わせて `cycles.csv` の `label` と `opt` を付けてください。

### Step C: 実機書き込みと `.hex` 高速差し替え

```bat
:: 1. 指定した構成と .hex でビットストリーム生成 (初回のみ Performance_Explore, 2回目以降は高速 Incremental)
hw\fpga\build_bit.bat RV32IM_Zbb_C0_Accel build\programs\raytracer\main_ar.hex

:: 2. FPGA へ書き込み (50 MHz 動作で PPM 完全一致と cycles / instret を記録)
hw\fpga\program_fpga.bat
```

### Step D: 計測結果を CSV にまとめて比較表を自動生成

以下のような `cycles.csv` を用意し（`instret` は省略可）、`tools/eval_table.py` を実行します。

```csv
label,opt,hw_config,cycles,instret
O0_base,-O0,RV32IM_pipemul,322506334843,228460940306
O3_zbb,-O3,RV32IM_Zbb,317433514069,226565935882
O3_math,-O3,RV32IM_Zbb_C0,244312299470,174867980599
O3_full,-O3,RV32IM_Zbb_C0_Accel,16394559321,11419389700
```

```sh
# HW 単体サマリ表のみ確認
python3 tools/eval_table.py

# HW × SW 結合表（50MHz実時間・限界Fmax実時間・LUT/DSP効率）を生成
python3 tools/eval_table.py --cycles cycles.csv --baseline O0_base --out-csv build/eval_summary.csv
```

---

## 3. 進捗チェックリスト

- [x] Vivado Sweep による 7 構成の面積・Post-Route $F_{\max}$ 計測 (`build/vivado_sweep/summary.csv`)
- [x] `uart_tx_fifo.sv` の Distributed RAM 分離（VGA 合流前の回路規模最適化）
- [ ] `-O0` / `-O1` / `-O2` / `-O3` の `.hex` を `build_bit.bat` で差し替えて実測 `cycles` / `instret` を記録
- [ ] `tools/eval_table.py` で発表用比較表・CSV を出力
- [ ] `feat/video_sub`（VGA 出力）合流後、`run_sweep.bat search RV32IM_Zbb_C0_Accel explore` で最終 SoC リソース・$F_{\max}$ を更新
