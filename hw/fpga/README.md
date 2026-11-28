# RaySC-V FPGA 評価・ビルドガイド (Windows / Arty A7-100T)

ターゲットボード: **Digilent Arty A7-100T / Nexys A7-100T (`xc7a100tcsg324-1`)**

Vivado の場所は `PATH`(`vivado.bat`)，環境変数 `VIVADO_BIN`，または `C:\Xilinx\Vivado\*` / `C:\AMDDesignTools\*` から自動検出．

---

## 1. 全構成の回路規模 (LUT/DSP) と最大動作周波数 ($F_{\max}$) 一括計測

リポジトリルートで以下を実行します(コマンドプロンプト / PowerShell 共通)．

```bat
:: 全20構成を 50MHz 基準計測 + 二分探索 Fmax 計測 (推奨)
hw\fpga\run_sweep.bat

:: 高速見積もりモード (50MHz + 1回のタイト制約のみ)
hw\fpga\run_sweep.bat fast

:: 特定の 1 構成だけ計測したい場合
hw\fpga\run_sweep.bat search RV32IM_Zbb_C0_Accel_pipe1

:: Performance_Explore (-directive Explore) で配置配線を頑張って計測したい場合 (VGA 合流後など)
hw\fpga\run_sweep.bat search RV32IM_Zbb_C0_Accel_pipe1 explore
```

### 評価される構成一覧 (`configs.tcl`)

命名規則: **`<ISA/機能スタック>[_<乗算方式>]`**

* `_comb1` : `PIPE_MUL=0, MUL_STALL=1, QMUL_STALL=1`（組合せ乗算 1ストール = 2cyc、`main` 既定）
* `_comb0` : `PIPE_MUL=0, MUL_STALL=0, QMUL_STALL=0`（組合せ乗算 0ストール = 1cyc）
* `_pipe1` : `PIPE_MUL=1, MUL_STALL=1, QMUL_STALL=1`（3段パイプライン乗算 = 3cyc）
* `_pipe1_q0` : `PIPE_MUL=1, MUL_STALL=1, QMUL_STALL=0`（3段パイプライン乗算 + `qmul` 0ストール）

| 構成名 | M (MUL/DIV) | Zbb | custom-0 内訳 | 球アクセラレータ | 乗算方式 |
| --- | :---: | :---: | --- | :---: | --- |
| `RV32I` | OFF | OFF | - | OFF | - |
| `RV32I_MulOnly_pipe1` | MULのみ | OFF | - | OFF | `_pipe1` |
| `RV32IM_comb1` | MUL+DIV | OFF | - | OFF | `_comb1` |
| `RV32IM_comb0` | MUL+DIV | OFF | - | OFF | `_comb0` |
| `RV32IM_pipe1` | MUL+DIV | OFF | - | OFF | `_pipe1` |
| `RV32IM_Zbb_comb1` | MUL+DIV | ON | - | OFF | `_comb1` |
| `RV32IM_Zbb_comb0` | MUL+DIV | ON | - | OFF | `_comb0` |
| `RV32IM_Zbb_pipe1` | MUL+DIV | ON | - | OFF | `_pipe1` |
| `RV32IM_Zbb_Rand_comb1` | MUL+DIV | ON | **`QRAND` のみ** | OFF | `_comb1` |
| `RV32IM_Zbb_Rand_pipe1` | MUL+DIV | ON | **`QRAND` のみ** | OFF | `_pipe1` |
| `RV32IM_Zbb_QmulSqrt_pipe1` | MUL+DIV | ON | **`QMUL` + `QSQRT` のみ** | OFF | `_pipe1` |
| `RV32IM_Zbb_MathOnly_pipe1` | MUL+DIV | ON | `QMUL/QSQRT/QRSQRT/QRCP` (`QRAND=0`) | OFF | `_pipe1` |
| `RV32IM_Zbb_C0_comb1` | MUL+DIV | ON | 全部 (`QMUL/QSQRT/QRSQRT/QRCP/QRAND`) | OFF | `_comb1` |
| `RV32IM_Zbb_C0_comb0` | MUL+DIV | ON | 全部 | OFF | `_comb0` |
| `RV32IM_Zbb_C0_pipe1` | MUL+DIV | ON | 全部 | OFF | `_pipe1` |
| `RV32IM_Zbb_C0_pipe1_q0` | MUL+DIV | ON | 全部 | OFF | `_pipe1_q0` |
| `RV32IM_Zbb_Rand_Accel_pipe1` | MUL+DIV | ON | **`QRAND` のみ** | ON | `_pipe1` |
| `RV32IM_Zbb_C0_Accel_comb1` | MUL+DIV | ON | 全部 | ON | `_comb1` |
| `RV32IM_Zbb_C0_Accel_comb0` | MUL+DIV | ON | 全部 | ON | `_comb0` |
| `RV32IM_Zbb_C0_Accel_pipe1` | MUL+DIV | ON | 全部 | ON | `_pipe1` |

※ `build_bit.bat` では `RV32IM_Zbb_C0_Accel_pipe1_q0`（`_pipe1_q0`、全機能 ON）、および VGA 出力有効化構成（`ENABLE_VGA=1`）の `RV32IM_Zbb_C0_Accel_comb1_VGA` / `RV32IM_Zbb_C0_Accel_comb0_VGA` / `RV32IM_Zbb_C0_Accel_pipe1_VGA` も指定可能です（これら `*_VGA` 構成は `hw\fpga\run_sweep.bat search <構成名> explore` でも個別計測できます）。
※ `sweep` 全 20 構成をまとめて回す場合は時間がかかるため，特定構成のみを `hw\fpga\run_sweep.bat search <構成名>` で個別追加計測することもできます(`summary.csv` の該当行を上書き・追記します)．

### 結果の確認

* **集計 CSV**: `build\vivado_sweep\summary.csv`
  * `lut_50m`, `ff_50m`, `bram_50m`, `dsp_50m`, `cpu_lut_50m`, `cpu_ff_50m`, `wns_50m_ns`: 50MHz 制約時の回路規模・CPU 単体規模・余裕度
  * `fmax_pass_mhz`, `pass_period_ns`, `wns_pass_ns`: Post-Route STA で `WNS >= 0` を満たした実測上限周波数
  * `est_fmax_mhz`: `1000 / (pass_period_ns - wns_pass_ns)` による理論限界見積もり
  * `crit_startpoint`, `crit_endpoint`: クリティカルパスの始点・終点ピン名
* **詳細レポート**: `build\vivado_sweep\<構成名>\` 内の `util_50mhz.rpt`, `util_hier_50mhz.rpt`, `timing_50mhz.rpt`, `timing_fmax.rpt`, `util_hier_fmax.rpt`
* **比較表の自動生成**: `python3 tools/eval_table.py`(詳細は [hw/fpga/eval_plan.md](eval_plan.md) を参照)

---

## 2. 任意の `.hex` を埋め込んでビットストリーム生成 (高速差し替え対応)

```bat
:: 50 MHz (CLK_DIV=16) でビットストリームを生成 (VGA OFF)
hw\fpga\build_bit.bat RV32IM_Zbb_C0_Accel_pipe1 build\programs\raytracer\main_ar.hex

:: 50 MHz (CLK_DIV=16) + VGA 有効化 (MMIO 0x4000_0000 書き込み表示)
hw\fpga\build_bit.bat RV32IM_Zbb_C0_Accel_comb1_VGA build\programs\raytracer\main_ar.hex

:: VRAM 初期画像テスト (起動直後からモニター表示確認したい場合)
hw\fpga\build_bit.bat RV32IM_Zbb_C0_Accel_comb1_VGA build\tests\hex\smoke.hex 16 tests\hex\vram_raytracer.hex

:: 周波数を変えて試す場合 (例: CLK_DIV=10 -> 800/10 = 80 MHz, UART ボーレート自動追従)
hw\fpga\build_bit.bat RV32IM_pipe1 build\tests\hex\smoke.hex 10
```

* Pmod VGA ピン制約（[arty_a7.xdc](../constraints/arty_a7.xdc)）は実機確認済みの **Pmod JA + JB**（JA=R/B、JB=G/HSYNC/VSYNC）を既定としています。Pmod JB + JC 接続を使う場合は `arty_a7.xdc` 内の予備コメント側へ差し替えてください。

* 出力先: `build\vivado_bit\<構成名>\<hexファイル名>.bit` および `build\vivado_bit\latest.bit`
* 既定では毎回 **`Performance_Explore` (`-directive Explore` での `opt`/`place`/`phys_opt`/`route`)** を使用して高品質なビットストリームを生成します(Vivado Standard/BASIC ライセンスでの Incremental 制限 `[Vivado 12-29181]` を回避するため既定 OFF)．
* 有償ライセンス環境等で Incremental Implementation を使う場合は，第 4 引数 `1` を指定して `build_bit.tcl` を実行すると基準チェックポイント (`routed_ref_div<CLK_DIV>.dcp`) を利用できます．

---

## 3. FPGA への書き込み

```bat
:: 直前に build_bit.bat で生成した latest.bit を書き込む
hw\fpga\program_fpga.bat

:: 任意の .bit を指定して書き込む場合
hw\fpga\program_fpga.bat build\vivado_bit\RV32IM_Zbb_C0_Accel_pipe1\main_ar.bit
```
