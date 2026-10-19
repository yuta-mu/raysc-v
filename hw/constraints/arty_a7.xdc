# ==============================================================================
# Clocks
# ==============================================================================
set_property -dict { PACKAGE_PIN E3    IOSTANDARD LVCMOS33 } [get_ports { CLK100MHZ }];
create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} [get_ports { CLK100MHZ }];

# 50MHz 内部生成クロック (BUFG 出力端子に対して制約)
create_generated_clock -name clk_50m -source [get_ports CLK100MHZ] -divide_by 2 [get_pins u_bufg/O];

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
# Configuration Constraints (ビットストリーム圧縮 & SPI 読み出し高速化)
# ==============================================================================
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
