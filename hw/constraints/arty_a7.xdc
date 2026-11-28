# ==============================================================================
# Clocks
# ==============================================================================
set_property -dict { PACKAGE_PIN E3    IOSTANDARD LVCMOS33 } [get_ports { CLK100MHZ }];
create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} [get_ports { CLK100MHZ }];

# ==============================================================================
# Reset Button (Active-Low: ボード上の赤い RESET ボタン)
# ==============================================================================
set_property -dict { PACKAGE_PIN C2    IOSTANDARD LVCMOS33 } [get_ports { ck_rst }];

# ==============================================================================
# USB-UART (FTDI チップ経由で PC のシリアルポートに見えるピン)
# ==============================================================================
set_property -dict { PACKAGE_PIN D10   IOSTANDARD LVCMOS33 } [get_ports { uart_tx }];

# ==============================================================================
# 4 On-board Green LEDs (LD4 - LD7)
# ==============================================================================
set_property -dict { PACKAGE_PIN H5    IOSTANDARD LVCMOS33 } [get_ports { led[0] }]; # LD4
set_property -dict { PACKAGE_PIN J5    IOSTANDARD LVCMOS33 } [get_ports { led[1] }]; # LD5
set_property -dict { PACKAGE_PIN T9    IOSTANDARD LVCMOS33 } [get_ports { led[2] }]; # LD6
set_property -dict { PACKAGE_PIN T10   IOSTANDARD LVCMOS33 } [get_ports { led[3] }]; # LD7

# ==============================================================================
# Pmod VGA (Pmod JA + JB 実機確認済み構成)
#   JA (J1): R[0..3] (JA1-4), B[0..3] (JA7-10)
#   JB (J2): G[0..3] (JB1-4), HSYNC/VSYNC (JB7-8)
# ==============================================================================
set_property -dict { PACKAGE_PIN G13   IOSTANDARD LVCMOS33 } [get_ports { vga_r[0] }]; # JA1
set_property -dict { PACKAGE_PIN B11   IOSTANDARD LVCMOS33 } [get_ports { vga_r[1] }]; # JA2
set_property -dict { PACKAGE_PIN A11   IOSTANDARD LVCMOS33 } [get_ports { vga_r[2] }]; # JA3
set_property -dict { PACKAGE_PIN D12   IOSTANDARD LVCMOS33 } [get_ports { vga_r[3] }]; # JA4
set_property -dict { PACKAGE_PIN D13   IOSTANDARD LVCMOS33 } [get_ports { vga_b[0] }]; # JA7
set_property -dict { PACKAGE_PIN B18   IOSTANDARD LVCMOS33 } [get_ports { vga_b[1] }]; # JA8
set_property -dict { PACKAGE_PIN A18   IOSTANDARD LVCMOS33 } [get_ports { vga_b[2] }]; # JA9
set_property -dict { PACKAGE_PIN K16   IOSTANDARD LVCMOS33 } [get_ports { vga_b[3] }]; # JA10

set_property -dict { PACKAGE_PIN E15   IOSTANDARD LVCMOS33 } [get_ports { vga_g[0] }]; # JB1
set_property -dict { PACKAGE_PIN E16   IOSTANDARD LVCMOS33 } [get_ports { vga_g[1] }]; # JB2
set_property -dict { PACKAGE_PIN D15   IOSTANDARD LVCMOS33 } [get_ports { vga_g[2] }]; # JB3
set_property -dict { PACKAGE_PIN C15   IOSTANDARD LVCMOS33 } [get_ports { vga_g[3] }]; # JB4
set_property -dict { PACKAGE_PIN J17   IOSTANDARD LVCMOS33 } [get_ports { vga_hsync }]; # JB7
set_property -dict { PACKAGE_PIN J18   IOSTANDARD LVCMOS33 } [get_ports { vga_vsync }]; # JB8

# ------------------------------------------------------------------------------
# (予備) High-Speed Pmod JB + JC に接続している場合は上の JA + JB をコメントアウトし以下を有効化
# ------------------------------------------------------------------------------
#set_property -dict { PACKAGE_PIN E15   IOSTANDARD LVCMOS33 } [get_ports { vga_r[0] }]; # JB1
#set_property -dict { PACKAGE_PIN E16   IOSTANDARD LVCMOS33 } [get_ports { vga_r[1] }]; # JB2
#set_property -dict { PACKAGE_PIN D15   IOSTANDARD LVCMOS33 } [get_ports { vga_r[2] }]; # JB3
#set_property -dict { PACKAGE_PIN C15   IOSTANDARD LVCMOS33 } [get_ports { vga_r[3] }]; # JB4
#set_property -dict { PACKAGE_PIN J17   IOSTANDARD LVCMOS33 } [get_ports { vga_b[0] }]; # JB7
#set_property -dict { PACKAGE_PIN J18   IOSTANDARD LVCMOS33 } [get_ports { vga_b[1] }]; # JB8
#set_property -dict { PACKAGE_PIN K15   IOSTANDARD LVCMOS33 } [get_ports { vga_b[2] }]; # JB9
#set_property -dict { PACKAGE_PIN J15   IOSTANDARD LVCMOS33 } [get_ports { vga_b[3] }]; # JB10
#set_property -dict { PACKAGE_PIN U12   IOSTANDARD LVCMOS33 } [get_ports { vga_g[0] }]; # JC1
#set_property -dict { PACKAGE_PIN V12   IOSTANDARD LVCMOS33 } [get_ports { vga_g[1] }]; # JC2
#set_property -dict { PACKAGE_PIN V10   IOSTANDARD LVCMOS33 } [get_ports { vga_g[2] }]; # JC3
#set_property -dict { PACKAGE_PIN V11   IOSTANDARD LVCMOS33 } [get_ports { vga_g[3] }]; # JC4
#set_property -dict { PACKAGE_PIN U14   IOSTANDARD LVCMOS33 } [get_ports { vga_hsync }]; # JC7
#set_property -dict { PACKAGE_PIN V14   IOSTANDARD LVCMOS33 } [get_ports { vga_vsync }]; # JC8

# ------------------------------------------------------------------------------
# CPU クロック (u_bufg/O) と VGA ピクセルクロック (gen_vga.u_vga_display/u_bufg_150m/O) は
# 非同期 CDC 関係 (sweep.tcl / build_bit.tcl は ENABLE_VGA=1 時のみ Tcl で自動適用).
# Vivado GUI ビルド時に警告が出る場合は以下を有効化:
# set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins u_bufg/O]] -group [get_clocks -of_objects [get_pins gen_vga.u_vga_display/u_bufg_150m/O]]
# ------------------------------------------------------------------------------

# ==============================================================================
# Configuration Constraints (ビットストリーム圧縮 & SPI 読み出し高速化)
# ==============================================================================
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
