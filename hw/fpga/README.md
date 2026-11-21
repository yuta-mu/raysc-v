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
hw\fpga\run_sweep.bat search RV32IM_Zbb_C0_Accel

:: Performance_Explore (-directive Explore) で配置配線を頑張って計測したい場合 (VGA 合流後など)
hw\fpga\run_sweep.bat search RV32IM_Zbb_C0_Accel explore
```

### 評価される構成一覧 (`configs.tcl`)

| 構成名 | M (MUL/DIV) | Zbb | custom-0 内訳 | 球アクセラレータ | 乗算方式 (`PIPE_MUL` / `MUL_STALL` / `QMUL_STALL`) |
| --- | :---: | :---: | --- | :---: | --- |
| `RV32I` | OFF | OFF | - | OFF | - |
| `RV32I_MulOnly` | MULのみ | OFF | - | OFF | `PIPE=1` (3cyc) |
| `RV32IM_base` | MUL+DIV | OFF | - | OFF | `PIPE=0, MUL_STALL=1` (2cyc) |
| `RV32IM_zerostall` | MUL+DIV | OFF | - | OFF | `PIPE=0, MUL_STALL=0` (1cyc) |
| `RV32IM_pipemul` | MUL+DIV | OFF | - | OFF | `PIPE=1` (3cyc) |
| `RV32IM_Zbb_base` | MUL+DIV | ON | - | OFF | `PIPE=0, MUL_STALL=1` (2cyc) |
| `RV32IM_Zbb_zerostall` | MUL+DIV | ON | - | OFF | `PIPE=0, MUL_STALL=0` (1cyc) |
| `RV32IM_Zbb` | MUL+DIV | ON | - | OFF | `PIPE=1` (3cyc) |
| `RV32IM_Zbb_Rand_base` | MUL+DIV | ON | **`QRAND` のみ** | OFF | `PIPE=0, MUL_STALL=1` (2cyc) |
| `RV32IM_Zbb_Rand` | MUL+DIV | ON | **`QRAND` のみ** | OFF | `PIPE=1` (3cyc) |
| `RV32IM_Zbb_QmulSqrt` | MUL+DIV | ON | **`QMUL` + `QSQRT` のみ** | OFF | `PIPE=1` (3cyc) |
| `RV32IM_Zbb_MathOnly` | MUL+DIV | ON | `QMUL/QSQRT/QRSQRT/QRCP` (`QRAND=0`) | OFF | `PIPE=1` (3cyc) |
| `RV32IM_Zbb_C0_base` | MUL+DIV | ON | 全部 (`QMUL/QSQRT/QRSQRT/QRCP/QRAND`) | OFF | `PIPE=0, MUL_STALL=1, QMUL_STALL=1` |
| `RV32IM_Zbb_C0_zerostall` | MUL+DIV | ON | 全部 | OFF | `PIPE=0, MUL_STALL=0, QMUL_STALL=0` (1cyc) |
| `RV32IM_Zbb_C0` | MUL+DIV | ON | 全部 | OFF | `PIPE=1, QMUL_STALL=1` |
| `RV32IM_Zbb_C0_nostall` | MUL+DIV | ON | 全部 | OFF | `PIPE=1, QMUL_STALL=0` |
| `RV32IM_Zbb_Rand_Accel` | MUL+DIV | ON | **`QRAND` のみ** | ON | `PIPE=1` (3cyc) |
| `full` | MUL+DIV | ON | 全部 | ON | `PIPE=0, MUL_STALL=1, QMUL_STALL=1` (`main` 既定値) |
| `full_zerostall` | MUL+DIV | ON | 全部 | ON | `PIPE=0, MUL_STALL=0, QMUL_STALL=0` (50MHz 理論最速) |
| `RV32IM_Zbb_C0_Accel` | MUL+DIV | ON | 全部 | ON | `PIPE=1, QMUL_STALL=1` |

※ `build_bit.bat` では `full_nostall` (`PIPE=1, MUL_STALL=1, QMUL_STALL=0`, 全機能 ON) も指定可能です．
※ `sweep` 全 20 構成をまとめて回す場合は時間がかかるため，特定構成のみを `hw\fpga\run_sweep.bat search <構成名>` で個別追加計測することもできます(`summary.csv` に追記されます)．

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
:: 50 MHz (CLK_DIV=16) でビットストリームを生成
hw\fpga\build_bit.bat RV32IM_Zbb_C0_Accel build\programs\raytracer\main_ar.hex

:: 周波数を変えて試す場合 (例: CLK_DIV=10 -> 800/10 = 80 MHz, UART ボーレート自動追従)
hw\fpga\build_bit.bat RV32IM_pipemul build\tests\hex\smoke.hex 10
```

* 出力先: `build\vivado_bit\<構成名>\<hexファイル名>.bit` および `build\vivado_bit\latest.bit`
* 初回 PnR は自動で **`Performance_Explore` (`-directive Explore`)** を使用して高品質な基準チェックポイント (`routed_ref_div<CLK_DIV>.dcp`) を保存．
* 同じ `<構成名>` と `CLK_DIV` での 2 回目以降は **Incremental Implementation** が自動有効化され，`.hex` 差し替えビルドが高速化されます．RTL (`hw/rtl/*.sv`, `*.svh`) または XDC を更新した場合は，タイムスタンプ比較により自動でフル PnR をやり直して基準チェックポイントを更新．

---

## 3. FPGA への書き込み

```bat
:: 直前に build_bit.bat で生成した latest.bit を書き込む
hw\fpga\program_fpga.bat

:: 任意の .bit を指定して書き込む場合
hw\fpga\program_fpga.bat build\vivado_bit\RV32IM_Zbb_C0_Accel\main_ar.bit
```
