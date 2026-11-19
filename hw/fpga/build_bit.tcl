# ==============================================================================
# RaySC-V Bitstream Builder with Easy .hex Swapping & Incremental PnR
# Usage:
#   vivado -mode batch -source hw/fpga/build_bit.tcl -tclargs <config> <hex_path> [clk_div]
#   Example:
#     vivado -mode batch -source hw/fpga/build_bit.tcl -tclargs RV32IM_Zbb_C0_Accel build/programs/raytracer/main_ar.hex 16
# ==============================================================================

if {$argc < 2} {
    puts "ERROR: Usage: vivado -mode batch -source hw/fpga/build_bit.tcl -tclargs <config> <hex_path> \[clk_div=16\]"
    exit 1
}

set script_dir [file dirname [file normalize [info script]]]
set repo_root  [file normalize [file join $script_dir ".." ".."]]
source [file join $script_dir "configs.tcl"]

set cfg_name [lindex $argv 0]
set hex_in   [lindex $argv 1]
set clk_div  16
if {$argc >= 3 && [lindex $argv 2] ne ""} {
    set clk_div [lindex $argv 2]
}

if {![info exists CONFIG_PARAMS($cfg_name)]} {
    puts "ERROR: Unknown config '$cfg_name'. Valid configs: [lsort [array names CONFIG_PARAMS]]"
    exit 1
}

if {[file pathtype $hex_in] eq "relative"} {
    set hex_abs [file normalize [file join $repo_root $hex_in]]
} else {
    set hex_abs [file normalize $hex_in]
}

if {![file exists $hex_abs]} {
    puts "ERROR: HEX file not found: $hex_abs"
    exit 1
}

set hex_stem [file rootname [file tail $hex_abs]]
set freq_mhz [format "%.2f" [expr {800.0 / $clk_div}]]

set bit_root [file join $repo_root "build" "vivado_bit"]
set cfg_dir  [file join $bit_root $cfg_name]
file mkdir $cfg_dir

set rtl_dir   [file join $repo_root "hw" "rtl"]
set rtl_files [lsort [glob -nocomplain [file join $rtl_dir "*.sv"]]]
set xdc_file  [file join $repo_root "hw" "constraints" "arty_a7.xdc"]

puts "======================================================================"
puts "Building Bitstream"
puts "  Config  : $cfg_name"
puts "  HEX     : $hex_abs"
puts "  CLK_DIV : $clk_div ($freq_mhz MHz)"
puts "======================================================================"

create_project -in_memory -part $FPGA_PART
set_property include_dirs [list $rtl_dir] [current_fileset]
foreach f $rtl_files {
    read_verilog -sv $f
}
read_xdc $xdc_file

set gen_args [get_config_generic_args $cfg_name]
lappend gen_args -generic "CLK_DIV=$clk_div"
lappend gen_args -generic [format {INIT_FILE="%s"} $hex_abs]

synth_design -top top -part $FPGA_PART -include_dirs [list $rtl_dir] {*}$gen_args
opt_design -directive Explore
fix_ramb36_cascade_addr15

set ref_dcp [file join $cfg_dir "routed_ref_div${clk_div}.dcp"]
set use_inc 0
if {[file exists $ref_dcp]} {
    set ref_mtime [file mtime $ref_dcp]
    set src_files [concat \
        [glob -nocomplain [file join $rtl_dir "*.sv"]] \
        [glob -nocomplain [file join $rtl_dir "*.svh"]] \
        [list $xdc_file]]
    set stale 0
    foreach sf $src_files {
        if {[file mtime $sf] > $ref_mtime} {
            set stale 1
            puts "INFO: Source newer than $ref_dcp ($sf); refreshing reference checkpoint."
            break
        }
    }
    if {!$stale} {
        set use_inc 1
    }
}

if {$use_inc} {
    puts "Incremental implementation enabled using reference: $ref_dcp"
    read_checkpoint -incremental $ref_dcp
    place_design
    phys_opt_design
    fix_ramb36_cascade_addr15
    route_design
} else {
    puts "Running full Performance_Explore PnR (reference checkpoint will be saved for future fast .hex swaps)..."
    place_design -directive Explore
    phys_opt_design -directive Explore
    fix_ramb36_cascade_addr15
    route_design -directive Explore
    write_checkpoint -force $ref_dcp
}

set util_str [report_utilization -return_string]
lassign [extract_util_metrics $util_str] luts ffs bram dsp
lassign [extract_timing_metrics] wns sp ep

report_utilization -file [file join $cfg_dir "${hex_stem}_util.rpt"]
report_timing_summary -delay_type max -max_paths 5 -file [file join $cfg_dir "${hex_stem}_timing.rpt"]

set bit_out [file join $cfg_dir "${hex_stem}.bit"]
set latest_bit [file join $bit_root "latest.bit"]
write_bitstream -force $bit_out
file copy -force $bit_out $latest_bit

puts "======================================================================"
puts [format "Build Complete: %s" $bit_out]
puts [format "  Latest Copy : %s" $latest_bit]
puts [format "  Utilization : LUT=%s  FF=%s  BRAM=%s  DSP=%s" $luts $ffs $bram $dsp]
puts [format "  Timing      : WNS=%s ns (Start=%s -> End=%s)" $wns $sp $ep]
if {$wns ne "NA" && $wns < 0.0} {
    puts "WARNING: Timing NOT met (WNS < 0)! Consider increasing CLK_DIV or enabling PIPE_MUL."
}
puts "======================================================================"
