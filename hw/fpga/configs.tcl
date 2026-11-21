# ==============================================================================
# RaySC-V ハードウェア評価構成テーブル (Arty A7-100T / xc7a100tcsg324-1)
# sweep.tcl および build_bit.tcl から共通参照される
# ==============================================================================

set FPGA_PART "xc7a100tcsg324-1"

# sweep.tcl で評価する構成順 (機能追加・切り分け × 乗算パイプライン有無のトレードオフ階段)
set SWEEP_CONFIGS [list \
    "RV32I" \
    "RV32I_MulOnly" \
    "RV32IM_base" \
    "RV32IM_zerostall" \
    "RV32IM_pipemul" \
    "RV32IM_Zbb_base" \
    "RV32IM_Zbb_zerostall" \
    "RV32IM_Zbb" \
    "RV32IM_Zbb_Rand_base" \
    "RV32IM_Zbb_Rand" \
    "RV32IM_Zbb_QmulSqrt" \
    "RV32IM_Zbb_MathOnly" \
    "RV32IM_Zbb_C0_base" \
    "RV32IM_Zbb_C0_zerostall" \
    "RV32IM_Zbb_C0" \
    "RV32IM_Zbb_C0_nostall" \
    "RV32IM_Zbb_Rand_Accel" \
    "full" \
    "full_zerostall" \
    "RV32IM_Zbb_C0_Accel" \
]

# 各構成の top.sv パラメータ定義
#   M  DIV ZBB C0 QMUL QSQRT QRSQRT QRCP QRAND ACCEL PIPE_MUL MUL_STALL QMUL_STALL
array set CONFIG_PARAMS {
    RV32I                   {0 0 0 0 0 0 0 0 0 0 0 1 1}
    RV32I_MulOnly           {1 0 0 0 0 0 0 0 0 0 1 1 1}
    RV32IM_base             {1 1 0 0 0 0 0 0 0 0 0 1 1}
    RV32IM_zerostall        {1 1 0 0 0 0 0 0 0 0 0 0 1}
    RV32IM_pipemul          {1 1 0 0 0 0 0 0 0 0 1 1 1}
    RV32IM_Zbb_base         {1 1 1 0 0 0 0 0 0 0 0 1 1}
    RV32IM_Zbb_zerostall    {1 1 1 0 0 0 0 0 0 0 0 0 1}
    RV32IM_Zbb              {1 1 1 0 0 0 0 0 0 0 1 1 1}
    RV32IM_Zbb_Rand_base    {1 1 1 1 0 0 0 0 1 0 0 1 1}
    RV32IM_Zbb_Rand         {1 1 1 1 0 0 0 0 1 0 1 1 1}
    RV32IM_Zbb_QmulSqrt     {1 1 1 1 1 1 0 0 0 0 1 1 1}
    RV32IM_Zbb_MathOnly     {1 1 1 1 1 1 1 1 0 0 1 1 1}
    RV32IM_Zbb_C0_base      {1 1 1 1 1 1 1 1 1 0 0 1 1}
    RV32IM_Zbb_C0_zerostall {1 1 1 1 1 1 1 1 1 0 0 0 0}
    RV32IM_Zbb_C0           {1 1 1 1 1 1 1 1 1 0 1 1 1}
    RV32IM_Zbb_C0_nostall   {1 1 1 1 1 1 1 1 1 0 1 1 0}
    RV32IM_Zbb_Rand_Accel   {1 1 1 1 0 0 0 0 1 1 1 1 1}
    RV32IM_Zbb_C0_Accel     {1 1 1 1 1 1 1 1 1 1 1 1 1}
    full                    {1 1 1 1 1 1 1 1 1 1 0 1 1}
    full_nostall            {1 1 1 1 1 1 1 1 1 1 1 1 0}
    full_zerostall          {1 1 1 1 1 1 1 1 1 1 0 0 0}
}

proc get_config_generic_args {cfg_name} {
    global CONFIG_PARAMS
    if {![info exists CONFIG_PARAMS($cfg_name)]} {
        set valid [lsort [array names CONFIG_PARAMS]]
        error "Unknown config '$cfg_name'. Valid configs: $valid"
    }
    lassign $CONFIG_PARAMS($cfg_name) \
        en_m en_div en_zbb en_c0 en_qmul en_qsqrt en_qrsqrt en_qrcp en_qrand en_accel pipe_mul mul_stall qmul_stall
    return [list \
        -generic "ENABLE_M=$en_m" \
        -generic "ENABLE_DIV=$en_div" \
        -generic "ENABLE_ZBB=$en_zbb" \
        -generic "ENABLE_CUSTOM0=$en_c0" \
        -generic "ENABLE_QMUL=$en_qmul" \
        -generic "ENABLE_QSQRT=$en_qsqrt" \
        -generic "ENABLE_QRSQRT=$en_qrsqrt" \
        -generic "ENABLE_QRCP=$en_qrcp" \
        -generic "ENABLE_QRAND=$en_qrand" \
        -generic "ENABLE_SPHERE_ACCEL=$en_accel" \
        -generic "PIPE_MUL=$pipe_mul" \
        -generic "MUL_STALL=$mul_stall" \
        -generic "QMUL_STALL=$qmul_stall" \
    ]
}

proc extract_util_metrics {util_str} {
    set luts "NA"
    set ffs  "NA"
    set bram "NA"
    set dsp  "NA"

    if {![regexp -line -- {\|\s*Slice LUTs[^|]*\|\s*([0-9]+)} $util_str -> luts]} {
        regexp -line -- {\|\s*CLB LUTs[^|]*\|\s*([0-9]+)} $util_str -> luts
    }
    if {![regexp -line -- {\|\s*Slice Registers[^|]*\|\s*([0-9]+)} $util_str -> ffs]} {
        regexp -line -- {\|\s*Register as Flip Flop[^|]*\|\s*([0-9]+)} $util_str -> ffs
    }
    regexp -line -- {\|\s*Block RAM Tile[^|]*\|\s*([0-9.]+)} $util_str -> bram
    regexp -line -- {\|\s*DSPs[^|]*\|\s*([0-9]+)} $util_str -> dsp

    return [list $luts $ffs $bram $dsp]
}

proc extract_cpu_util_metrics {hier_util_str} {
    set cpu_luts "NA"
    set cpu_ffs  "NA"
    regexp -line -- {\|\s*u_cpu\s*\|\s*cpu\s*\|\s*([0-9]+)\s*\|\s*[0-9]+\s*\|\s*[0-9]+\s*\|\s*[0-9]+\s*\|\s*([0-9]+)\s*\|} $hier_util_str -> cpu_luts cpu_ffs
    return [list $cpu_luts $cpu_ffs]
}

proc parse_timing_endpoints {rpt_str} {
    set sp "NA"
    set ep "NA"
    regexp -line -- {^\s*Source:\s+(\S+)} $rpt_str -> sp
    regexp -line -- {^\s*Destination:\s+(\S+)} $rpt_str -> ep
    return [list $sp $ep]
}

proc extract_timing_metrics {} {
    set tps [get_timing_paths -max_paths 1 -nworst 1 -setup]
    if {[llength $tps] == 0} {
        return [list "NA" "NA" "NA"]
    }
    set tp  [lindex $tps 0]
    set wns [get_property SLACK $tp]
    set rpt [report_timing -max_paths 1 -nworst 1 -delay_type max -return_string]
    lassign [parse_timing_endpoints $rpt] sp ep
    return [list $wns $sp $ep]
}

# Vivado 2024.1+ / 2026.1 で発生する RAMB36E1 カスケード段間の ADDR15 不一致 (DRC REQP-1962) を修復するガード
proc fix_ramb36_cascade_addr15 {} {
    set fixed 0
    foreach {ext_prop cas_in_pin addr_pin} {
        RAM_EXTENSION_A CASCADEINA {ADDRARDADDR[15]}
        RAM_EXTENSION_B CASCADEINB {ADDRBWRADDR[15]}
    } {
        set upper_cells [get_cells -hierarchical -quiet -filter "REF_NAME == RAMB36E1 && $ext_prop == UPPER"]
        foreach u_cell $upper_cells {
            set u_name [get_property NAME $u_cell]
            set u_cas_pin [get_pins -quiet [format {%s/%s} $u_name $cas_in_pin]]
            if {[llength $u_cas_pin] == 0} { continue }
            set cas_net [get_nets -quiet -of_objects $u_cas_pin]
            if {[llength $cas_net] == 0} { continue }
            set l_out_pins [get_pins -quiet -of_objects $cas_net -filter {DIRECTION == OUT}]
            if {[llength $l_out_pins] == 0} { continue }
            set l_cell [lindex [get_cells -quiet -of_objects [lindex $l_out_pins 0]] 0]
            if {$l_cell eq ""} { continue }
            set l_name [get_property NAME $l_cell]

            set u_addr_pin [get_pins -quiet [format {%s/%s} $u_name $addr_pin]]
            set l_addr_pin [get_pins -quiet [format {%s/%s} $l_name $addr_pin]]
            if {[llength $u_addr_pin] == 0 || [llength $l_addr_pin] == 0} { continue }

            set u_net [get_nets -quiet -of_objects $u_addr_pin]
            set l_net [get_nets -quiet -of_objects $l_addr_pin]
            if {[llength $u_net] == 0 || [llength $l_net] == 0} { continue }

            set u_net_name [get_property NAME $u_net]
            set l_net_name [get_property NAME $l_net]
            if {$u_net_name ne $l_net_name} {
                set u_type [get_property TYPE $u_net]
                set l_type [get_property TYPE $l_net]
                puts [format {INFO: [REQP-1962 guard] Mismatch on %s/%s (%s, %s) vs %s/%s (%s, %s)} \
                    $u_name $addr_pin $u_net_name $u_type $l_name $addr_pin $l_net_name $l_type]

                if {$u_type eq "SIGNAL" && $l_type ne "SIGNAL"} {
                    disconnect_net -net $l_net -objects $l_addr_pin
                    connect_net -hierarchical -net $u_net -objects $l_addr_pin
                } else {
                    disconnect_net -net $u_net -objects $u_addr_pin
                    connect_net -hierarchical -net $l_net -objects $u_addr_pin
                }
                incr fixed
            }
        }
    }
    if {$fixed > 0} {
        puts [format {INFO: [REQP-1962 guard] Unified %d cascaded RAMB36E1 ADDR15 pin(s).} $fixed]
    }
}
