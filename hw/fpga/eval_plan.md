# RaySC-V HW × コンパイラ最適化 評価チェックリスト

目的:
1. **HW 機能追加のトレードオフ**（「命令・回路を足せば常に速くなる」わけではないことの実証）
2. **コンパイラ最適化 (`-O0`〜`-O3`) の効果**（LUT/DSP/$F_{\max}$ ペナルティ 0 でどれだけ削れるか）
3. **ソフト最適化 vs ハードアクセラレーションの比較**（`Cycles / Fmax` の実時間、および `Speedup / kLUT`・`Speedup / DSP`）

---

## 1. 評価対象ハードウェア構成（`hw/fpga/configs.tcl`）

| 構成名 (`hw_config`) | 役割・主張ポイント |
| --- | --- |
| `RV32I` | DSP=0・最小回路面積・ベースライン上限 $F_{\max}$ の確認用（SW計測なし） |
| `RV32I_MulOnly_pipe1` | **M拡張の内訳切り分け**: `MUL` だけ（`DIV=0`）にして LUT の大半が除算器であることを示す（SW計測なし） |
| `RV32IM_comb1` / `_comb0` / `_pipe1` | **乗算パイプライン化の効用と代償**: 組合せ (`_comb1`: 1ストール / `_comb0`: 0ストール) vs 3サイクル (`_pipe1`) |
| `RV32IM_Zbb_comb1` / `_comb0` / `_pipe1` | **反例①**: Zbb 追加で命令数は微減するが $F_{\max}$ が低下し、限界周波数実時間が悪化し得ることを示す（`PIPE=0/1` 両方比較） |
| `RV32IM_Zbb_Rand_comb1` / `_pipe1` | **コスパ最強**: `custom-0` のうち `QRAND`（約数十LUT・0 DSP・0ストール）だけの面積/$F_{\max}$/速度効果 |
| `RV32IM_Zbb_QmulSqrt_pipe1` | **犯人特定**: `qrsqrt`/`qrcp` を抜いた `qmul+qsqrt` だけの $F_{\max}$ を測り、55MHz 低下の主因を切り分け |
| `RV32IM_Zbb_MathOnly_pipe1` | `custom-0` 算術4種のみ（`QRAND=0`）の面積・$F_{\max}$ |
| `RV32IM_Zbb_C0_comb1` / `_comb0` / `_pipe1` / `_pipe1_q0` | **反例②**: `custom-0` 全部入り（`qrsqrt` 律速で $F_{\max}$ が下がるため、`_pipe1` がむしろ逆効果になり得る検証） |
| `RV32IM_Zbb_Rand_Accel_pipe1` | **アクセラレータ単体の $F_{\max}$ 検証**: `qrcp`/`qrsqrt` なしで `Accel + QRAND` のみの限界周波数 |
| `RV32IM_Zbb_C0_Accel_comb1` / `_comb0` / `_pipe1` / (`_pipe1_q0`) | **本命**: DSP 192 個 (80%)・LUT 増・配線混雑下での `_comb1` / `_comb0` vs `_pipe1` の直接対決 |

---

## 2. 測定ワークフロー

### Step A: ハードウェア単体の面積・限界 $F_{\max}$ 計測（`ENABLE_VGA=0` で計測）

```bat
hw\fpga\run_sweep.bat
```

※ `.hex`（`-O0`〜`-O3`）を変えても LUT / DSP / $F_{\max}$ は変わらないため、**RTL や XDC を変更しない限り再実行は不要** です。
※ 今後 `feat/video_sub`（VGA 出力）をマージした際は、`ENABLE_VGA=1` 相当で最終 SoC 規模・$F_{\max}$ を確認するため以下を 1 回実行してください（サイクル数自体は独立 VRAM なら同一 `.hex` で不変）。

```bat
hw\fpga\run_sweep.bat search RV32IM_Zbb_C0_Accel_pipe1 explore
```

### Step B: `.hex` 生成（コンパイラ最適化 × アクセラレータ組合せ）

最新コンパイラは `feat/c11-isect` ブランチの `rayqc`、レイトレーサ `.rq` は `main` ブランチの `main.rq` / `main_ar.rq` を使用します。
`-O0`: なし / `-O1`: inline + fold / `-O2`: + regalloc / `-O3`: ロード使用ハザード回避・局所CSE・強度削減（コンパイラ班実装予定）。

#### 実測対象を絞った推奨セット（計 24〜28 本）

1. **最適化効果 (`-O0` / `-O1` / `-O2` / `-O3`) × 代表 HW 4段階**（各 4本 = 16本）
   - `RV32IM_pipe1` : `main.rq` × `--march=rv32im --accel=off` (`O0..O3`)
   - `RV32IM_Zbb_pipe1` : `main.rq` × `--march=rv32im_zbb --accel=off` (`O0..O3`)
   - `RV32IM_Zbb_C0_pipe1` : `main.rq` × `--march=rv32im_zbb --accel=math` (`O0..O3`)
   - `RV32IM_Zbb_C0_Accel_pipe1` : `main_ar.rq` × `--march=rv32im_zbb --accel=isect` (`O0..O3`)
2. **乗算/ストール方式 (`_comb1` / `_comb0` / `_pipe1` / `_pipe1_q0`) の横比較**（`-O2` または `-O3` 固定、計 10本 + Zbb 対照 1〜2本）
   - `RV32IM_comb1` / `RV32IM_comb0` (`--accel=off`)
   - `RV32IM_Zbb_comb1` / `RV32IM_Zbb_comb0` (`--accel=off`)
   - `RV32IM_Zbb_C0_comb1` / `RV32IM_Zbb_C0_comb0` / `RV32IM_Zbb_C0_pipe1_q0` (`--accel=math`)
   - `RV32IM_Zbb_C0_Accel_comb1` / `RV32IM_Zbb_C0_Accel_comb0` / `RV32IM_Zbb_C0_Accel_pipe1_q0` (`--accel=isect`)

| ラベル例 | プログラム | `RAYQ_FLAGS` | 対応 HW 構成 (`hw_config`) |
| --- | --- | --- | --- |
| `O0_base` | `programs/raytracer/main.rq` | `-O0 --march=rv32im --accel=off` | `RV32IM_pipe1` |
| `O1_base` | `programs/raytracer/main.rq` | `-O1 --march=rv32im --accel=off` | `RV32IM_pipe1` |
| `O2_base` | `programs/raytracer/main.rq` | `-O2 --march=rv32im --accel=off` | `RV32IM_pipe1` |
| `O3_base` | `programs/raytracer/main.rq` | `-O3 --march=rv32im --accel=off` | `RV32IM_pipe1` |
| `O3_zbb` | `programs/raytracer/main.rq` | `-O3 --march=rv32im_zbb --accel=off` | `RV32IM_Zbb_pipe1` |
| `O0_math` | `programs/raytracer/main.rq` | `-O0 --march=rv32im_zbb --accel=math` | `RV32IM_Zbb_C0_pipe1` |
| `O1_math` | `programs/raytracer/main.rq` | `-O1 --march=rv32im_zbb --accel=math` | `RV32IM_Zbb_C0_pipe1` |
| `O2_math` | `programs/raytracer/main.rq` | `-O2 --march=rv32im_zbb --accel=math` | `RV32IM_Zbb_C0_pipe1` |
| `O3_math` | `programs/raytracer/main.rq` | `-O3 --march=rv32im_zbb --accel=math` | `RV32IM_Zbb_C0_pipe1` |
| `O0_isect` | `programs/raytracer/main_ar.rq` | `-O0 --march=rv32im_zbb --accel=isect` | `RV32IM_Zbb_C0_Accel_pipe1` |
| `O1_isect` | `programs/raytracer/main_ar.rq` | `-O1 --march=rv32im_zbb --accel=isect` | `RV32IM_Zbb_C0_Accel_pipe1` |
| `O2_isect` | `programs/raytracer/main_ar.rq` | `-O2 --march=rv32im_zbb --accel=isect` | `RV32IM_Zbb_C0_Accel_pipe1` |
| `O3_isect` | `programs/raytracer/main_ar.rq` | `-O3 --march=rv32im_zbb --accel=isect` | `RV32IM_Zbb_C0_Accel_pipe1` |
| `O3_isect_comb0` | `programs/raytracer/main_ar.rq` | `-O3 --march=rv32im_zbb --accel=isect` | `RV32IM_Zbb_C0_Accel_comb0` |

### Step C: 実機書き込みと `.hex` 差し替えビルド

```bat
:: 1. 指定した構成と .hex でビットストリーム生成 (既定は毎回 Performance_Explore)
hw\fpga\build_bit.bat RV32IM_Zbb_C0_Accel_pipe1 build\programs\raytracer\main_ar.hex

:: 2. FPGA へ書き込み (50 MHz 動作で PPM 完全一致と cycles / instret を記録)
hw\fpga\program_fpga.bat
```

### Step D: 計測結果を CSV にまとめて比較表を自動生成

以下のような `cycles.csv` を用意し（`instret` は省略可）、`tools/eval_table.py` を実行します。

```csv
label,opt,hw_config,cycles,instret
O0_base,-O0,RV32IM_pipe1,322506334843,228460940306
O3_zbb,-O3,RV32IM_Zbb_pipe1,317433514069,226565935882
O3_math,-O3,RV32IM_Zbb_C0_pipe1,244312299470,174867980599
O3_full,-O3,RV32IM_Zbb_C0_Accel_pipe1,16394559321,11419389700
```

```sh
# HW 単体サマリ表のみ確認
python3 tools/eval_table.py

# HW × SW 結合表（50MHz実時間・限界Fmax実時間・LUT/DSP効率）を生成
python3 tools/eval_table.py --cycles cycles.csv --baseline O0_base --out-csv build/eval_summary.csv
```

---

## 3. 進捗チェックリスト

- [x] HW パラメータ化・評価スクリプト整備 (`hw/fpga/configs.tcl` 命名規則統一済み)
- [x] `uart_tx_fifo.sv` の Distributed RAM 分離（VGA 合流前の回路規模最適化）
- [x] 全20構成の面積・Post-Route $F_{\max}$ 計測 (`hw\fpga\run_sweep.bat`)
- [ ] `-O0` / `-O1` / `-O2` / `-O3` の `.hex` を `build_bit.bat` で差し替えて実測 `cycles` / `instret` を記録
- [ ] `tools/eval_table.py` で発表用比較表・CSV を出力
- [ ] `feat/video_sub`（VGA 出力）合流後、`ENABLE_VGA=1` 相当で最終 SoC リソース・$F_{\max}$ を更新（必要なら `run_sweep.bat search RV32IM_Zbb_C0_Accel_pipe1 explore`）
