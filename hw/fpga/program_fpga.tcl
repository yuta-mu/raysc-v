# ==============================================================================
# RaySC-V FPGA Programmer (Arty A7-100T / xc7a100t)
# Usage:
#   vivado -mode batch -source hw/fpga/program_fpga.tcl [-tclargs path/to/file.bit]
# ==============================================================================

set script_dir [file dirname [file normalize [info script]]]
set repo_root  [file normalize [file join $script_dir ".." ".."]]

if {$argc >= 1 && [lindex $argv 0] ne ""} {
    set bit_in [lindex $argv 0]
    if {[file pathtype $bit_in] eq "relative"} {
        set bit_path [file normalize [file join $repo_root $bit_in]]
    } else {
        set bit_path [file normalize $bit_in]
    }
} else {
    set bit_path [file join $repo_root "build" "vivado_bit" "latest.bit"]
}

if {![file exists $bit_path]} {
    puts "ERROR: Bitstream not found: $bit_path"
    exit 1
}

puts "Programming FPGA with: $bit_path"

open_hw_manager
connect_hw_server -allow_non_jtag
open_hw_target

set devs [get_hw_devices xc7a100t*]
if {[llength $devs] == 0} {
    set devs [get_hw_devices]
}
if {[llength $devs] == 0} {
    puts "ERROR: No FPGA hardware device found."
    exit 1
}

set dev [lindex $devs 0]
current_hw_device $dev
refresh_hw_device -update_hw_probes false $dev
set_property PROGRAM.FILE $bit_path $dev
program_hw_devices $dev
refresh_hw_device $dev

close_hw_target
disconnect_hw_server
close_hw_manager

puts "FPGA programming succeeded: $bit_path"
