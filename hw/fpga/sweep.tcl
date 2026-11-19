# ==============================================================================
# RaySC-V FPGA Sweep & Fmax Search Script (Vivado Batch)
# Usage:
#   vivado -mode batch -source hw/fpga/sweep.tcl [-tclargs [mode] [config_filter] [strategy]]
#   mode         : search (default: 50MHz + bisection Fmax) | fast (50MHz + 1 tight pass)
#   config_filter: all (default) | <config_name>
#   strategy     : default (default) | explore (-directive Explore)
# ==============================================================================

set script_dir [file dirname [file normalize [info script]]]
set repo_root  [file normalize [file join $script_dir ".." ".."]]
source [file join $script_dir "configs.tcl"]

set mode "search"
set cfg_filter "all"
set strategy "default"
if {$argc >= 1 && [lindex $argv 0] ne ""} {
    set mode [lindex $argv 0]
}
if {$argc >= 2 && [lindex $argv 1] ne ""} {
    set cfg_filter [lindex $argv 1]
}
if {$argc >= 3 && [lindex $argv 2] ne ""} {
    set strategy [lindex $argv 2]
}

if {$mode ne "search" && $mode ne "fast"} {
    puts "ERROR: Invalid mode '$mode'. Use 'search' or 'fast'."
    exit 1
}
if {$strategy ne "default" && $strategy ne "explore"} {
    puts "ERROR: Invalid strategy '$strategy'. Use 'default' or 'explore'."
    exit 1
}

if {$cfg_filter eq "all"} {
    set target_configs $SWEEP_CONFIGS
} else {
    if {![info exists CONFIG_PARAMS($cfg_filter)]} {
        puts "ERROR: Unknown config '$cfg_filter'. Available: [lsort [array names CONFIG_PARAMS]]"
        exit 1
    }
    set target_configs [list $cfg_filter]
}

set out_root [file join $repo_root "build" "vivado_sweep"]
file mkdir $out_root

# XDC から物理ピン制約のみ抽出 (create_clock / BITSTREAM を除外して PLL 制約衝突を回避)
set orig_xdc [file join $repo_root "hw" "constraints" "arty_a7.xdc"]
set pins_xdc [file join $out_root "pins_only.xdc"]
set fin  [open $orig_xdc r]
set fout [open $pins_xdc w]
while {[gets $fin line] >= 0} {
    if {[regexp {^\s*(create_clock|set_property\s+BITSTREAM)} $line]} {
        continue
    }
    puts $fout $line
}
close $fin
close $fout

set rtl_dir [file join $repo_root "hw" "rtl"]
set rtl_files [lsort [glob -nocomplain [file join $rtl_dir "*.sv"]]]
if {[llength $rtl_files] == 0} {
    puts "ERROR: No .sv files found in $rtl_dir"
    exit 1
}

set csv_path [file join $out_root "summary.csv"]
if {$cfg_filter eq "all" || ![file exists $csv_path]} {
    set fcsv [open $csv_path w]
    puts $fcsv "config,mode,strategy,lut_50m,ff_50m,bram_50m,dsp_50m,cpu_lut_50m,cpu_ff_50m,wns_50m_ns,fmax_pass_mhz,pass_period_ns,wns_pass_ns,est_fmax_mhz,lut_fmax,ff_fmax,dsp_fmax,crit_startpoint,crit_endpoint"
    close $fcsv
}

proc fmt_num {fmt val} {
    if {$val eq "NA" || $val eq ""} {
        return "NA"
    }
    return [format $fmt $val]
}

proc round_025 {val} {
    return [expr {round($val * 4.0) / 4.0}]
}

proc run_pnr_pass {dcp_path period use_phys_opt strategy cfg_dir write_rpt_prefix} {
    catch {close_design}
    catch {close_project}
    open_checkpoint $dcp_path

    # u_bufg/O を直接拘束し，PLL VCO 範囲に縛られず任意の周期で STA を行う
    set clk_pins [get_pins -quiet u_bufg/O]
    if {[llength $clk_pins] == 0} {
        error "Clock pin u_bufg/O not found in checkpoint"
    }
    create_clock -name sys_clk -period $period $clk_pins

    if {$strategy eq "explore"} {
        place_design -directive Explore
        if {$use_phys_opt} {
            phys_opt_design -directive Explore
            fix_ramb36_cascade_addr15
        }
        route_design -directive Explore
    } else {
        place_design
        if {$use_phys_opt} {
            phys_opt_design
            fix_ramb36_cascade_addr15
        }
        route_design
    }

    set util_str [report_utilization -return_string]
    set hier_str [report_utilization -hierarchical -return_string]
    lassign [extract_util_metrics $util_str] luts ffs bram dsp
    lassign [extract_cpu_util_metrics $hier_str] cpu_luts cpu_ffs
    lassign [extract_timing_metrics] wns sp ep

    if {$write_rpt_prefix ne ""} {
        report_utilization -file [file join $cfg_dir "util_${write_rpt_prefix}.rpt"]
        report_utilization -hierarchical -file [file join $cfg_dir "util_hier_${write_rpt_prefix}.rpt"]
        report_timing_summary -delay_type max -max_paths 5 -file [file join $cfg_dir "timing_${write_rpt_prefix}.rpt"]
    }

    set passed 0
    if {$wns ne "NA" && $wns >= 0.0} {
        set passed 1
    }

    return [list $passed $wns $period $luts $ffs $bram $dsp $sp $ep $cpu_luts $cpu_ffs]
}

proc save_winning_reports {cfg_dir} {
    report_utilization -file [file join $cfg_dir "util_fmax.rpt"]
    report_utilization -hierarchical -file [file join $cfg_dir "util_hier_fmax.rpt"]
    report_timing_summary -delay_type max -max_paths 5 -file [file join $cfg_dir "timing_fmax.rpt"]
}

foreach cfg $target_configs {
    puts "======================================================================"
    puts "Sweeping config: $cfg (mode=$mode, strategy=$strategy)"
    puts "======================================================================"

    set cfg_dir [file join $out_root $cfg]
    file mkdir $cfg_dir

    catch {close_design}
    catch {close_project}
    create_project -in_memory -part $FPGA_PART
    set_property include_dirs [list $rtl_dir] [current_fileset]
    foreach f $rtl_files {
        read_verilog -sv $f
    }
    read_xdc $pins_xdc

    set gen_args [get_config_generic_args $cfg]
    lappend gen_args -generic {INIT_FILE="NONE"}

    synth_design -top top -part $FPGA_PART -include_dirs [list $rtl_dir] {*}$gen_args
    if {$strategy eq "explore"} {
        opt_design -directive Explore
    } else {
        opt_design
    }
    fix_ramb36_cascade_addr15

    set opt_dcp [file join $cfg_dir "synth_opt.dcp"]
    write_checkpoint -force $opt_dcp
    close_project

    # --- Pass 0: 50 MHz (20.000 ns) 基準計測 ---
    set res50 [run_pnr_pass $opt_dcp 20.000 0 $strategy $cfg_dir "50mhz"]
    lassign $res50 pass50 wns50 p50 lut50 ff50 bram50 dsp50 sp50 ep50 cpu_lut50 cpu_ff50
    puts [format {  [50MHz] LUT=%s (u_cpu=%s) FF=%s (u_cpu=%s) BRAM=%s DSP=%s WNS=%s ns} \
        $lut50 $cpu_lut50 $ff50 $cpu_ff50 $bram50 $dsp50 $wns50]

    set best_pass_res ""
    if {$pass50} {
        set best_pass_res $res50
        save_winning_reports $cfg_dir
    }

    if {$mode eq "fast"} {
        set target_p [round_025 [expr {max(6.0, (20.0 - $wns50) * 0.90)}]]
        set res_fast [run_pnr_pass $opt_dcp $target_p 1 $strategy $cfg_dir ""]
        lassign $res_fast p_ok wns_f p_f lut_f ff_f bram_f dsp_f sp_f ep_f
        set est_fmax [format "%.2f" [expr {1000.0 / ($p_f - $wns_f)}]]
        if {$p_ok} {
            save_winning_reports $cfg_dir
            set fmax_pass [format "%.2f" [expr {1000.0 / $p_f}]]
            set pass_p    [format "%.2f" $p_f]
            set wns_pass  [format "%.3f" $wns_f]
            set lut_fm $lut_f; set ff_fm $ff_f; set dsp_fm $dsp_f; set sp_fm $sp_f; set ep_fm $ep_f
        } elseif {$pass50} {
            set fmax_pass "50.00"
            set pass_p    "20.00"
            set wns_pass  [format "%.3f" $wns50]
            set lut_fm $lut50; set ff_fm $ff50; set dsp_fm $dsp50; set sp_fm $sp50; set ep_fm $ep50
        } else {
            save_winning_reports $cfg_dir
            set fmax_pass "FAIL"
            set pass_p    "NA"
            set wns_pass  [format "%.3f" $wns_f]
            set lut_fm $lut_f; set ff_fm $ff_f; set dsp_fm $dsp_f; set sp_fm $sp_f; set ep_fm $ep_f
        }
    } else {
        # --- search モード: [lo_fail, hi_pass] ブラケッティング + 二分探索 ---
        set lo_fail ""
        set hi_pass ""

        if {$pass50} {
            set hi_pass 20.00
            set probe [round_025 [expr {max(4.0, (20.0 - $wns50) * 0.85)}]]
            if {$probe >= $hi_pass} {
                set probe [round_025 [expr {$hi_pass - 0.50}]]
            }
            set step 0
            while {$step < 3} {
                set res [run_pnr_pass $opt_dcp $probe 1 $strategy $cfg_dir ""]
                lassign $res ok wns_r p_r
                puts [format {  [Bracket %d] period=%.2fns -> WNS=%s ns (pass=%d)} $step $p_r $wns_r $ok]
                if {$ok} {
                    set hi_pass $p_r
                    set best_pass_res $res
                    save_winning_reports $cfg_dir
                    if {$p_r <= 4.0} {
                        set lo_fail 3.50
                        break
                    }
                    set next_p [round_025 [expr {max(3.5, ($p_r - $wns_r) * 0.85)}]]
                    if {$next_p >= $hi_pass} {
                        set next_p [round_025 [expr {$hi_pass - 0.50}]]
                    }
                    set probe $next_p
                } else {
                    set lo_fail $p_r
                    break
                }
                incr step
            }
            if {$lo_fail eq ""} {
                set lo_fail [round_025 [expr {max(3.0, $hi_pass - 2.0)}]]
            }
        } else {
            set lo_fail 20.00
            set probe [round_025 [expr {(20.0 - $wns50) * 1.10}]]
            if {$probe <= $lo_fail} {
                set probe [round_025 [expr {$lo_fail + 1.00}]]
            }
            set step 0
            while {$step < 4} {
                set res [run_pnr_pass $opt_dcp $probe 1 $strategy $cfg_dir ""]
                lassign $res ok wns_r p_r
                puts [format {  [BracketUp %d] period=%.2fns -> WNS=%s ns (pass=%d)} $step $p_r $wns_r $ok]
                if {$ok} {
                    set hi_pass $p_r
                    set best_pass_res $res
                    save_winning_reports $cfg_dir
                    break
                } else {
                    set lo_fail $p_r
                    set probe [round_025 [expr {min(60.0, ($p_r - $wns_r) * 1.15)}]]
                    if {$probe <= $lo_fail} {
                        set probe [round_025 [expr {$lo_fail + 1.00}]]
                    }
                }
                incr step
            }
        }

        # 二分探索 (最大 4 回, 分解能 0.50 ns)
        if {$hi_pass ne "" && $lo_fail ne ""} {
            set iter 0
            while {$iter < 4 && ($hi_pass - $lo_fail) > 0.50} {
                set mid [round_025 [expr {($lo_fail + $hi_pass) / 2.0}]]
                if {$mid <= $lo_fail || $mid >= $hi_pass} {
                    break
                }
                set res [run_pnr_pass $opt_dcp $mid 1 $strategy $cfg_dir ""]
                lassign $res ok wns_r p_r
                puts [format {  [Bisect %d] [%.2f, %.2f] mid=%.2fns -> WNS=%s ns (pass=%d)} $iter $lo_fail $hi_pass $p_r $wns_r $ok]
                if {$ok} {
                    set hi_pass $p_r
                    set best_pass_res $res
                    save_winning_reports $cfg_dir
                } else {
                    set lo_fail $p_r
                }
                incr iter
            }
        }

        if {$best_pass_res ne ""} {
            lassign $best_pass_res ok_f wns_f p_f lut_fm ff_fm bram_fm dsp_fm sp_fm ep_fm
            set fmax_pass [format "%.2f" [expr {1000.0 / $p_f}]]
            set pass_p    [format "%.2f" $p_f]
            set wns_pass  [format "%.3f" $wns_f]
            set est_fmax  [format "%.2f" [expr {1000.0 / ($p_f - $wns_f)}]]
        } else {
            set fmax_pass "FAIL"
            set pass_p    "NA"
            set wns_pass  [format "%.3f" $wns50]
            set est_fmax  [format "%.2f" [expr {1000.0 / (20.0 - $wns50)}]]
            set lut_fm $lut50; set ff_fm $ff50; set dsp_fm $dsp50; set sp_fm $sp50; set ep_fm $ep50
        }
    }

    catch {close_design}
    catch {close_project}

    set row [join [list \
        $cfg $mode $strategy $lut50 $ff50 $bram50 $dsp50 $cpu_lut50 $cpu_ff50 [fmt_num "%.3f" $wns50] \
        $fmax_pass $pass_p $wns_pass $est_fmax $lut_fm $ff_fm $dsp_fm \
        "\"$sp_fm\"" "\"$ep_fm\""] ","]

    set fcsv [open $csv_path a]
    puts $fcsv $row
    close $fcsv
    puts "  ==> RESULT $cfg: Fmax_pass=$fmax_pass MHz (period=$pass_p ns, WNS=$wns_pass ns, LUT_50m=$lut50, u_cpu_LUT=$cpu_lut50, DSP_50m=$dsp50)"
}

puts "======================================================================"
puts "Sweep finished. Summary CSV: $csv_path"
puts "======================================================================"
