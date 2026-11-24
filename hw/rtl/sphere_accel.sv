`timescale 1ns / 1ps

module sphere_accel #(
    parameter bit USE_ROUND = 1'b1
) (
    input  logic        clk,
    input  logic        rst_n,

    // MMIO バスインターフェース (Base: 0x3000_0000, サイズ 4KB)
    input  logic        sel,        // mem_valid && (mem_addr[31:12] == 20'h30000)
    input  logic        we,         // Store enable (sw)
    input  logic        re,         // Load enable  (lw)
    input  logic [11:0] addr_offset,// mem_addr[11:0]
    input  logic [31:0] wdata,
    output logic [31:0] rdata,
    output logic        stall       // CPU MEMステージストール要求
);

    localparam int NUM_LANES = 4;
    localparam int NUM_BATCH = 16; // 16 batches * 4 lanes = 64 spheres

    // =========================================================================
    // 初期値定数テーブル (全64球)
    // =========================================================================
    function automatic logic signed [31:0] init_x_round(input int idx);
        case (idx)
            0:  init_x_round = 32'sd0;
            1:  init_x_round = -32'sd262144;
            2:  init_x_round = 32'sd262144;
            3:  init_x_round = -32'sd372244;
            4:  init_x_round = 32'sd449577;
            5:  init_x_round = -32'sd517734;
            6:  init_x_round = 32'sd405668;
            7:  init_x_round = -32'sd532808;
            8:  init_x_round = -32'sd231997;
            9:  init_x_round = 32'sd493486;
            10: init_x_round = -32'sd394527;
            11: init_x_round = 32'sd96993;
            12: init_x_round = -32'sd28836;
            13: init_x_round = 32'sd513802;
            14: init_x_round = 32'sd521667;
            15: init_x_round = -32'sd469893;
            16: init_x_round = -32'sd229376;
            17: init_x_round = -32'sd323748;
            18: init_x_round = 32'sd374211;
            19: init_x_round = -32'sd494797;
            20: init_x_round = -32'sd308019;
            21: init_x_round = 32'sd216924;
            22: init_x_round = 32'sd463340;
            23: init_x_round = 32'sd70779;
            24: init_x_round = 32'sd532808;
            25: init_x_round = 32'sd332923;
            26: init_x_round = -32'sd125829;
            27: init_x_round = -32'sd513147;
            28: init_x_round = 32'sd287048;
            29: init_x_round = -32'sd66847;
            30: init_x_round = 32'sd549192;
            31: init_x_round = 32'sd403046;
            32: init_x_round = -32'sd380109;
            33: init_x_round = -32'sd11141;
            34: init_x_round = -32'sd268698;
            35: init_x_round = 32'sd66191;
            36: init_x_round = 32'sd39977;
            37: init_x_round = -32'sd93716;
            38: init_x_round = -32'sd251003;
            39: init_x_round = 32'sd394527;
            40: init_x_round = 32'sd154665;
            41: init_x_round = 32'sd270664;
            42: init_x_round = -32'sd134349;
            43: init_x_round = 32'sd589824;
            44: init_x_round = 32'sd126484;
            45: init_x_round = -32'sd148111;
            46: init_x_round = -32'sd293601;
            47: init_x_round = -32'sd73400;
            48: init_x_round = 32'sd227410;
            49: init_x_round = -32'sd135004;
            50: init_x_round = -32'sd351928;
            51: init_x_round = 32'sd430572;
            52: init_x_round = 32'sd585892;
            53: init_x_round = 32'sd338166;
            54: init_x_round = 32'sd472515;
            55: init_x_round = -32'sd445645;
            56: init_x_round = 32'sd62259;
            57: init_x_round = -32'sd166461;
            58: init_x_round = -32'sd403702;
            59: init_x_round = -32'sd551813;
            60: init_x_round = 32'sd490209;
            61: init_x_round = -32'sd502661;
            62: init_x_round = 32'sd22938;
            63: init_x_round = -32'sd475791;
            default: init_x_round = 32'sd0;
        endcase
    endfunction

    function automatic logic signed [31:0] init_x_trunc(input int idx);
        case (idx)
            0:  init_x_trunc = 32'sd0;
            1:  init_x_trunc = -32'sd262144;
            2:  init_x_trunc = 32'sd262144;
            3:  init_x_trunc = -32'sd372244;
            4:  init_x_trunc = 32'sd449576;
            5:  init_x_trunc = -32'sd517734;
            6:  init_x_trunc = 32'sd405667;
            7:  init_x_trunc = -32'sd532807;
            8:  init_x_trunc = -32'sd231997;
            9:  init_x_trunc = 32'sd493486;
            10: init_x_trunc = -32'sd394526;
            11: init_x_trunc = 32'sd96993;
            12: init_x_trunc = -32'sd28835;
            13: init_x_trunc = 32'sd513802;
            14: init_x_trunc = 32'sd521666;
            15: init_x_trunc = -32'sd469893;
            16: init_x_trunc = -32'sd229376;
            17: init_x_trunc = -32'sd323747;
            18: init_x_trunc = 32'sd374210;
            19: init_x_trunc = -32'sd494796;
            20: init_x_trunc = -32'sd308019;
            21: init_x_trunc = 32'sd216924;
            22: init_x_trunc = 32'sd463339;
            23: init_x_trunc = 32'sd70778;
            24: init_x_trunc = 32'sd532807;
            25: init_x_trunc = 32'sd332922;
            26: init_x_trunc = -32'sd125829;
            27: init_x_trunc = -32'sd513146;
            28: init_x_trunc = 32'sd287047;
            29: init_x_trunc = -32'sd66846;
            30: init_x_trunc = 32'sd549191;
            31: init_x_trunc = 32'sd403046;
            32: init_x_trunc = -32'sd380108;
            33: init_x_trunc = -32'sd11141;
            34: init_x_trunc = -32'sd268697;
            35: init_x_trunc = 32'sd66191;
            36: init_x_trunc = 32'sd39976;
            37: init_x_trunc = -32'sd93716;
            38: init_x_trunc = -32'sd251002;
            39: init_x_trunc = 32'sd394526;
            40: init_x_trunc = 32'sd154664;
            41: init_x_trunc = 32'sd270663;
            42: init_x_trunc = -32'sd134348;
            43: init_x_trunc = 32'sd589824;
            44: init_x_trunc = 32'sd126484;
            45: init_x_trunc = -32'sd148111;
            46: init_x_trunc = -32'sd293601;
            47: init_x_trunc = -32'sd73400;
            48: init_x_trunc = 32'sd227409;
            49: init_x_trunc = -32'sd135004;
            50: init_x_trunc = -32'sd351928;
            51: init_x_trunc = 32'sd430571;
            52: init_x_trunc = 32'sd585891;
            53: init_x_trunc = 32'sd338165;
            54: init_x_trunc = 32'sd472514;
            55: init_x_trunc = -32'sd445644;
            56: init_x_trunc = 32'sd62259;
            57: init_x_trunc = -32'sd166461;
            58: init_x_trunc = -32'sd403701;
            59: init_x_trunc = -32'sd551813;
            60: init_x_trunc = 32'sd490209;
            61: init_x_trunc = -32'sd502661;
            62: init_x_trunc = 32'sd22937;
            63: init_x_trunc = -32'sd475791;
            default: init_x_trunc = 32'sd0;
        endcase
    endfunction

    function automatic logic signed [31:0] init_z_round(input int idx);
        case (idx)
            0:  init_z_round = 32'sd0;
            1:  init_z_round = 32'sd0;
            2:  init_z_round = 32'sd0;
            3:  init_z_round = -32'sd243794;
            4:  init_z_round = 32'sd220856;
            5:  init_z_round = -32'sd32113;
            6:  init_z_round = -32'sd2621;
            7:  init_z_round = -32'sd137626;
            8:  init_z_round = 32'sd112067;
            9:  init_z_round = 32'sd115999;
            10: init_z_round = 32'sd43254;
            11: init_z_round = 32'sd101581;
            12: init_z_round = 32'sd140902;
            13: init_z_round = -32'sd19005;
            14: init_z_round = 32'sd74056;
            15: init_z_round = 32'sd146145;
            16: init_z_round = 32'sd201196;
            17: init_z_round = -32'sd89784;
            18: init_z_round = 32'sd96993;
            19: init_z_round = 32'sd61604;
            20: init_z_round = 32'sd81920;
            21: init_z_round = -32'sd67502;
            22: init_z_round = -32'sd237240;
            23: init_z_round = -32'sd74056;
            24: init_z_round = -32'sd199229;
            25: init_z_round = 32'sd39977;
            26: init_z_round = -32'sd28180;
            27: init_z_round = 32'sd190710;
            28: init_z_round = 32'sd112722;
            29: init_z_round = 32'sd178258;
            30: init_z_round = 32'sd165151;
            31: init_z_round = -32'sd68157;
            32: init_z_round = 32'sd110100;
            33: init_z_round = -32'sd98304;
            34: init_z_round = -32'sd214303;
            35: init_z_round = -32'sd175636;
            36: init_z_round = 32'sd176292;
            37: init_z_round = 32'sd25559;
            38: init_z_round = -32'sd129106;
            39: init_z_round = 32'sd246415;
            40: init_z_round = -32'sd27525;
            41: init_z_round = -32'sd139592;
            42: init_z_round = 32'sd230687;
            43: init_z_round = -32'sd221512;
            44: init_z_round = 32'sd201196;
            45: init_z_round = -32'sd173015;
            46: init_z_round = 32'sd234619;
            47: init_z_round = 32'sd109445;
            48: init_z_round = 32'sd191365;
            49: init_z_round = 32'sd178913;
            50: init_z_round = -32'sd145490;
            51: init_z_round = 32'sd125174;
            52: init_z_round = 32'sd47841;
            53: init_z_round = -32'sd38666;
            54: init_z_round = 32'sd165151;
            55: init_z_round = -32'sd76677;
            56: init_z_round = -32'sd226099;
            57: init_z_round = 32'sd0;
            58: init_z_round = -32'sd22938;
            59: init_z_round = -32'sd211026;
            60: init_z_round = -32'sd144835;
            61: init_z_round = -32'sd197263;
            62: init_z_round = 32'sd243139;
            63: init_z_round = -32'sd142868;
            default: init_z_round = 32'sd0;
        endcase
    endfunction

    function automatic logic signed [31:0] init_z_trunc(input int idx);
        case (idx)
            0:  init_z_trunc = 32'sd0;
            1:  init_z_trunc = 32'sd0;
            2:  init_z_trunc = 32'sd0;
            3:  init_z_trunc = -32'sd243793;
            4:  init_z_trunc = 32'sd220856;
            5:  init_z_trunc = -32'sd32112;
            6:  init_z_trunc = -32'sd2621;
            7:  init_z_trunc = -32'sd137625;
            8:  init_z_trunc = 32'sd112066;
            9:  init_z_trunc = 32'sd115998;
            10: init_z_trunc = 32'sd43253;
            11: init_z_trunc = 32'sd101580;
            12: init_z_trunc = 32'sd140902;
            13: init_z_trunc = -32'sd19005;
            14: init_z_trunc = 32'sd74055;
            15: init_z_trunc = 32'sd146145;
            16: init_z_trunc = 32'sd201195;
            17: init_z_trunc = -32'sd89784;
            18: init_z_trunc = 32'sd96993;
            19: init_z_trunc = 32'sd61603;
            20: init_z_trunc = 32'sd81920;
            21: init_z_trunc = -32'sd67502;
            22: init_z_trunc = -32'sd237240;
            23: init_z_trunc = -32'sd74055;
            24: init_z_trunc = -32'sd199229;
            25: init_z_trunc = 32'sd39976;
            26: init_z_trunc = -32'sd28180;
            27: init_z_trunc = 32'sd190709;
            28: init_z_trunc = 32'sd112721;
            29: init_z_trunc = 32'sd178257;
            30: init_z_trunc = 32'sd165150;
            31: init_z_trunc = -32'sd68157;
            32: init_z_trunc = 32'sd110100;
            33: init_z_trunc = -32'sd98304;
            34: init_z_trunc = -32'sd214302;
            35: init_z_trunc = -32'sd175636;
            36: init_z_trunc = 32'sd176291;
            37: init_z_trunc = 32'sd25559;
            38: init_z_trunc = -32'sd129105;
            39: init_z_trunc = 32'sd246415;
            40: init_z_trunc = -32'sd27525;
            41: init_z_trunc = -32'sd139591;
            42: init_z_trunc = 32'sd230686;
            43: init_z_trunc = -32'sd221511;
            44: init_z_trunc = 32'sd201195;
            45: init_z_trunc = -32'sd173015;
            46: init_z_trunc = 32'sd234618;
            47: init_z_trunc = 32'sd109445;
            48: init_z_trunc = 32'sd191365;
            49: init_z_trunc = 32'sd178913;
            50: init_z_trunc = -32'sd145489;
            51: init_z_trunc = 32'sd125173;
            52: init_z_trunc = 32'sd47841;
            53: init_z_trunc = -32'sd38666;
            54: init_z_trunc = 32'sd165150;
            55: init_z_trunc = -32'sd76677;
            56: init_z_trunc = -32'sd226099;
            57: init_z_trunc = 32'sd0;
            58: init_z_trunc = -32'sd22937;
            59: init_z_trunc = -32'sd211025;
            60: init_z_trunc = -32'sd144834;
            61: init_z_trunc = -32'sd197263;
            62: init_z_trunc = 32'sd243138;
            63: init_z_trunc = -32'sd142868;
            default: init_z_trunc = 32'sd0;
        endcase
    endfunction

    localparam logic [0:63] INIT_DIEL = 64'b1001_0010_0001_1001_0000_0010_0000_0000_0000_0010_0000_0000_0001_0000_0000_0100;

    logic signed [31:0] sph_x   [0:NUM_LANES-1][0:NUM_BATCH-1];
    logic signed [31:0] sph_y   [0:NUM_LANES-1][0:NUM_BATCH-1];
    logic signed [31:0] sph_z   [0:NUM_LANES-1][0:NUM_BATCH-1];
    logic signed [31:0] sph_r   [0:NUM_LANES-1][0:NUM_BATCH-1];
    logic signed [31:0] sph_r2  [0:NUM_LANES-1][0:NUM_BATCH-1];
    logic               sph_diel[0:NUM_LANES-1][0:NUM_BATCH-1];

    initial begin
        int ln, bt;
        for (int i = 0; i < 64; i++) begin
            ln = i % 4;
            bt = i / 4;
            sph_x[ln][bt]    = USE_ROUND ? init_x_round(i) : init_x_trunc(i);
            sph_y[ln][bt]    = (i < 3) ? 32'sd65536 : 32'sd13107;
            sph_z[ln][bt]    = USE_ROUND ? init_z_round(i) : init_z_trunc(i);
            sph_r[ln][bt]    = (i < 3) ? 32'sd65536 : 32'sd13107;
            sph_r2[ln][bt]   = (i < 3) ? 32'sd65536 : 32'sd2621;
            sph_diel[ln][bt] = INIT_DIEL[i];
        end
    end

    // =========================================================================
    // レイ入力レジスタ & スキャン制御ステート
    // =========================================================================
    logic signed [31:0] ray_ox, ray_oy, ray_oz;
    logic signed [31:0] ray_dx, ray_dy, ray_dz;
    logic signed [31:0] ray_tmin;

    logic               busy;
    logic [4:0]         batch_idx;

    logic signed [31:0] closest_reg;
    logic signed [31:0] best_idx_reg;

    wire                in_valid   = busy && (batch_idx < 5'd16);
    wire  [3:0]         in_batch   = batch_idx[3:0];
    wire                in_last    = (batch_idx == 5'd15);
    wire                gnd_in_val = busy && (batch_idx == 5'd0); // バッチ0と同時に地面判定を起動

    assign stall = sel && re && busy && (addr_offset == 12'h020 || addr_offset == 12'h024);

    always_comb begin
        rdata = 32'd0;
        if (sel && re) begin
            case (addr_offset)
                12'h020: rdata = best_idx_reg;
                12'h024: rdata = closest_reg;
                12'h028: rdata = {31'd0, busy};
                default: rdata = 32'd0;
            endcase
        end
    end

    // 球テーブルの動的書き換え (0x100 〜 0x8FF)
    wire [11:0] tbl_offset = addr_offset - 12'h100;
    wire        tbl_we     = sel && we && !busy && (addr_offset >= 12'h100) && (addr_offset < 12'h900);
    wire [5:0]  tbl_s_idx  = tbl_offset[10:5];
    wire [1:0]  tbl_lane   = tbl_s_idx[1:0];
    wire [3:0]  tbl_batch  = tbl_s_idx[5:2];

    always_ff @(posedge clk) begin
        if (tbl_we) begin
            case (tbl_offset[4:0])
                5'h00: sph_x[tbl_lane][tbl_batch]    <= signed'(wdata);
                5'h04: sph_y[tbl_lane][tbl_batch]    <= signed'(wdata);
                5'h08: sph_z[tbl_lane][tbl_batch]    <= signed'(wdata);
                5'h0C: sph_r[tbl_lane][tbl_batch]    <= signed'(wdata);
                5'h10: sph_r2[tbl_lane][tbl_batch]   <= signed'(wdata);
                5'h14: sph_diel[tbl_lane][tbl_batch] <= (wdata == 32'd2);
                default: ;
            endcase
        end
    end

    // =========================================================================
    // 地面 (hit_ground_t, Index = 64) 専用パイプライン (17段: Cycle 17で完了)
    // =========================================================================
    // Stage G0: os = ray.o * 0.125 (算術右シフト3bitとBit-Exact同一)
    logic               g0_valid;
    logic signed [31:0] g0_osx, g0_osy, g0_osz;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) g0_valid <= 1'b0;
        else        g0_valid <= gnd_in_val;
    end
    always_ff @(posedge clk) begin
        g0_osx <= ray_ox >>> 3;
        g0_osy <= ray_oy >>> 3;
        g0_osz <= ray_oz >>> 3;
    end

    // Stage G1: os <.> ray.d, 125.0 * ray.d.y, os <.> os, 31.25 * ray.o.y の乗算
    logic               g1_valid;
    logic signed [31:0] g1_p0, g1_p1, g1_p2, g1_tb;
    logic signed [31:0] g1_q0, g1_q1, g1_q2, g1_tk;

    wire signed [63:0] gp_p0 = 64'(g0_osx) * 64'(ray_dx);
    wire signed [63:0] gp_p1 = 64'(g0_osy) * 64'(ray_dy);
    wire signed [63:0] gp_p2 = 64'(g0_osz) * 64'(ray_dz);
    wire signed [63:0] gp_tb = 64'(32'sd8192000) * 64'(ray_dy); // 125.0 * ray.d.y

    wire signed [63:0] gp_q0 = 64'(g0_osx) * 64'(g0_osx);
    wire signed [63:0] gp_q1 = 64'(g0_osy) * 64'(g0_osy);
    wire signed [63:0] gp_q2 = 64'(g0_osz) * 64'(g0_osz);
    wire signed [63:0] gp_tk = 64'(32'sd2048000) * 64'(ray_oy); // 31.25 * ray.o.y

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) g1_valid <= 1'b0;
        else        g1_valid <= g0_valid;
    end
    always_ff @(posedge clk) begin
        g1_p0 <= gp_p0[47:16];
        g1_p1 <= gp_p1[47:16];
        g1_p2 <= gp_p2[47:16];
        g1_tb <= gp_tb[47:16];
        g1_q0 <= gp_q0[47:16];
        g1_q1 <= gp_q1[47:16];
        g1_q2 <= gp_q2[47:16];
        g1_tk <= gp_tk[47:16];
    end

    // Stage G2: bs と ks の加算
    logic               g2_valid, g2_rej;
    logic signed [31:0] g2_bs, g2_ks;

    wire signed [31:0] g_bs_w = ((g1_p0 + g1_p1) + g1_p2) + g1_tb;
    wire signed [31:0] g_ks_w = ((g1_q0 + g1_q1) + g1_q2) + g1_tk;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) g2_valid <= 1'b0;
        else        g2_valid <= g1_valid;
    end
    always_ff @(posedge clk) begin
        g2_bs  <= g_bs_w;
        g2_ks  <= g_ks_w;
        g2_rej <= (g_bs_w >= 32'sd0);
    end

    // Stage G3: bs * bs
    logic               g3_valid, g3_rej;
    logic signed [31:0] g3_bs, g3_ks, g3_bs2;

    wire signed [63:0] gp_bs2 = 64'(g2_bs) * 64'(g2_bs);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) g3_valid <= 1'b0;
        else        g3_valid <= g2_valid;
    end
    always_ff @(posedge clk) begin
        g3_bs  <= g2_bs;
        g3_ks  <= g2_ks;
        g3_rej <= g2_rej;
        g3_bs2 <= gp_bs2[47:16];
    end

    // Stage G4: disc = bs * bs - ks
    logic               g4_valid, g4_rej;
    logic signed [31:0] g4_neg_bs;
    logic [47:0]        g4_rad;

    wire signed [31:0] g_disc_w = g3_bs2 - g3_ks;
    wire               g_disc_n = (g_disc_w < 32'sd0);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) g4_valid <= 1'b0;
        else        g4_valid <= g3_valid;
    end
    always_ff @(posedge clk) begin
        g4_neg_bs <= 32'sd0 - g3_bs;
        g4_rej    <= g3_rej || g_disc_n;
        g4_rad    <= (g3_rej || g_disc_n) ? 48'd0 : {g_disc_w[31:0], 16'd0};
    end

    // Stage G5..G16 (12段): 地面用 24bit Restoring Square Root
    logic               gsq_valid [1:12];
    logic               gsq_rej   [1:12];
    logic signed [31:0] gsq_neg_b [1:12];
    logic [47:0]        gsq_rad   [1:12];
    logic [27:0]        gsq_rem   [1:12];
    logic [23:0]        gsq_q     [1:12];

    genvar gst;
    generate
        for (gst = 0; gst < 12; gst++) begin : gen_gnd_sqrt
            logic               in_valid;
            logic               in_rej;
            logic signed [31:0] in_neg_b;
            logic [47:0]        in_rad;
            logic [27:0]        in_rem;
            logic [23:0]        in_q;

            if (gst == 0) begin : gen_in0
                assign in_valid = g4_valid;
                assign in_rej   = g4_rej;
                assign in_neg_b = g4_neg_bs;
                assign in_rad   = g4_rad;
                assign in_rem   = 28'd0;
                assign in_q     = 24'd0;
            end else begin : gen_inN
                assign in_valid = gsq_valid[gst];
                assign in_rej   = gsq_rej[gst];
                assign in_neg_b = gsq_neg_b[gst];
                assign in_rad   = gsq_rad[gst];
                assign in_rem   = gsq_rem[gst];
                assign in_q     = gsq_q[gst];
            end

            logic [27:0] rem1, test1, rem1_next;
            logic [23:0] q1;
            logic [27:0] rem2, test2, rem2_next;
            logic [23:0] q2;

            always_comb begin
                rem1  = {in_rem[25:0], in_rad[47:46]};
                test1 = {2'b00, in_q, 2'b01};
                if (rem1 >= test1) begin
                    rem1_next = rem1 - test1;
                    q1        = {in_q[22:0], 1'b1};
                end else begin
                    rem1_next = rem1;
                    q1        = {in_q[22:0], 1'b0};
                end

                rem2  = {rem1_next[25:0], in_rad[45:44]};
                test2 = {2'b00, q1, 2'b01};
                if (rem2 >= test2) begin
                    rem2_next = rem2 - test2;
                    q2        = {q1[22:0], 1'b1};
                end else begin
                    rem2_next = rem2;
                    q2        = {q1[22:0], 1'b0};
                end
            end

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) gsq_valid[gst+1] <= 1'b0;
                else        gsq_valid[gst+1] <= in_valid;
            end
            always_ff @(posedge clk) begin
                gsq_rej[gst+1]   <= in_rej;
                gsq_neg_b[gst+1] <= in_neg_b;
                gsq_rad[gst+1]   <= {in_rad[43:0], 4'd0};
                gsq_rem[gst+1]   <= rem2_next;
                gsq_q[gst+1]     <= q2;
            end
        end
    endgenerate

    // 地面の最終結果 (Cycle 17: 球のBatch 0が到着する1クロック前に確定)
    wire               gnd_fin_valid = gsq_valid[12];
    wire signed [31:0] gnd_sqrtd     = {8'd0, gsq_q[12]};
    wire signed [31:0] gnd_tau       = gsq_neg_b[12] - gnd_sqrtd;
    wire signed [63:0] gnd_root_prod = 64'(gnd_tau) * 64'(32'sd524288); // tau * 8.0
    wire signed [31:0] gnd_root      = gnd_root_prod[47:16];
    wire               gnd_hit_ok    = !gsq_rej[12] && (gnd_root > ray_tmin) && (gnd_root < closest_reg);

    // =========================================================================
    // 4レーン並列 球交差判定パイプライン (18段: Cycle 18..33で完了)
    // =========================================================================
    logic               lane_fin_valid [0:NUM_LANES-1];
    logic               lane_fin_last  [0:NUM_LANES-1];
    logic               lane_hit       [0:NUM_LANES-1];
    logic signed [31:0] lane_t         [0:NUM_LANES-1];
    logic [5:0]         lane_idx       [0:NUM_LANES-1];

    genvar g;
    generate
        for (g = 0; g < NUM_LANES; g++) begin : gen_lane
            // --- Stage 0 ---
            logic               s0_valid, s0_last;
            logic [5:0]         s0_idx;
            logic signed [31:0] s0_oc_x, s0_oc_y, s0_oc_z;
            logic signed [31:0] s0_r, s0_r2;
            logic               s0_diel;

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin s0_valid <= 1'b0; s0_last <= 1'b0; end
                else        begin s0_valid <= in_valid; s0_last <= in_valid && in_last; end
            end
            always_ff @(posedge clk) begin
                s0_idx  <= {in_batch, 2'(g)};
                s0_oc_x <= ray_ox - sph_x[g][in_batch];
                s0_oc_y <= ray_oy - sph_y[g][in_batch];
                s0_oc_z <= ray_oz - sph_z[g][in_batch];
                s0_r    <= sph_r[g][in_batch];
                s0_r2   <= sph_r2[g][in_batch];
                s0_diel <= sph_diel[g][in_batch];
            end

            // --- Stage 1 ---
            logic               s1_valid, s1_last;
            logic [5:0]         s1_idx;
            logic signed [31:0] s1_oc_x, s1_oc_y, s1_oc_z;
            logic signed [31:0] s1_r, s1_r2;
            logic               s1_diel;
            logic signed [31:0] s1_bx, s1_by, s1_bz;

            wire signed [63:0] prod_bx = 64'(s0_oc_x) * 64'(ray_dx);
            wire signed [63:0] prod_by = 64'(s0_oc_y) * 64'(ray_dy);
            wire signed [63:0] prod_bz = 64'(s0_oc_z) * 64'(ray_dz);

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin s1_valid <= 1'b0; s1_last <= 1'b0; end
                else        begin s1_valid <= s0_valid; s1_last <= s0_last; end
            end
            always_ff @(posedge clk) begin
                s1_idx  <= s0_idx;
                s1_oc_x <= s0_oc_x;
                s1_oc_y <= s0_oc_y;
                s1_oc_z <= s0_oc_z;
                s1_r    <= s0_r;
                s1_r2   <= s0_r2;
                s1_diel <= s0_diel;
                s1_bx   <= prod_bx[47:16];
                s1_by   <= prod_by[47:16];
                s1_bz   <= prod_bz[47:16];
            end

            // --- Stage 2 ---
            logic               s2_valid, s2_last;
            logic [5:0]         s2_idx;
            logic signed [31:0] s2_oc_x, s2_oc_y, s2_oc_z;
            logic signed [31:0] s2_r, s2_r2;
            logic               s2_diel;
            logic signed [31:0] s2_b, s2_neg_b, s2_min_t;
            logic               s2_reject;

            wire signed [31:0] b_sum   = (s1_bx + s1_by) + s1_bz;
            wire signed [31:0] neg_b_w = 32'sd0 - b_sum;

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin s2_valid <= 1'b0; s2_last <= 1'b0; end
                else        begin s2_valid <= s1_valid; s2_last <= s1_last; end
            end
            always_ff @(posedge clk) begin
                s2_idx    <= s1_idx;
                s2_oc_x   <= s1_oc_x;
                s2_oc_y   <= s1_oc_y;
                s2_oc_z   <= s1_oc_z;
                s2_r      <= s1_r;
                s2_r2     <= s1_r2;
                s2_diel   <= s1_diel;
                s2_b      <= b_sum;
                s2_neg_b  <= neg_b_w;
                s2_min_t  <= neg_b_w - s1_r;
                s2_reject <= (b_sum >= s1_r);
            end

            // --- Stage 3 ---
            logic               s3_valid, s3_last;
            logic [5:0]         s3_idx;
            logic signed [31:0] s3_oc_x, s3_oc_y, s3_oc_z;
            logic signed [31:0] s3_r, s3_r2;
            logic               s3_diel;
            logic signed [31:0] s3_neg_b, s3_min_t;
            logic               s3_reject;
            logic signed [31:0] s3_dbx, s3_dby, s3_dbz;

            wire signed [63:0] prod_dbx = 64'(ray_dx) * 64'(s2_b);
            wire signed [63:0] prod_dby = 64'(ray_dy) * 64'(s2_b);
            wire signed [63:0] prod_dbz = 64'(ray_dz) * 64'(s2_b);

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin s3_valid <= 1'b0; s3_last <= 1'b0; end
                else        begin s3_valid <= s2_valid; s3_last <= s2_last; end
            end
            always_ff @(posedge clk) begin
                s3_idx    <= s2_idx;
                s3_oc_x   <= s2_oc_x;
                s3_oc_y   <= s2_oc_y;
                s3_oc_z   <= s2_oc_z;
                s3_r      <= s2_r;
                s3_r2     <= s2_r2;
                s3_diel   <= s2_diel;
                s3_neg_b  <= s2_neg_b;
                s3_min_t  <= s2_min_t;
                s3_reject <= s2_reject;
                s3_dbx    <= prod_dbx[47:16];
                s3_dby    <= prod_dby[47:16];
                s3_dbz    <= prod_dbz[47:16];
            end

            // --- Stage 4 ---
            logic               s4_valid, s4_last;
            logic [5:0]         s4_idx;
            logic signed [31:0] s4_r2;
            logic               s4_diel;
            logic signed [31:0] s4_neg_b, s4_min_t;
            logic               s4_reject;
            logic signed [31:0] s4_px, s4_py, s4_pz;

            wire signed [31:0] px_w = s3_oc_x - s3_dbx;
            wire signed [31:0] py_w = s3_oc_y - s3_dby;
            wire signed [31:0] pz_w = s3_oc_z - s3_dbz;

            wire signed [31:0] abs_px = (px_w < 32'sd0) ? (32'sd0 - px_w) : px_w;
            wire signed [31:0] abs_py = (py_w < 32'sd0) ? (32'sd0 - py_w) : py_w;
            wire signed [31:0] abs_pz = (pz_w < 32'sd0) ? (32'sd0 - pz_w) : pz_w;
            wire               box_out = (abs_px > s3_r) || (abs_py > s3_r) || (abs_pz > s3_r);

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin s4_valid <= 1'b0; s4_last <= 1'b0; end
                else        begin s4_valid <= s3_valid; s4_last <= s3_last; end
            end
            always_ff @(posedge clk) begin
                s4_idx    <= s3_idx;
                s4_r2     <= s3_r2;
                s4_diel   <= s3_diel;
                s4_neg_b  <= s3_neg_b;
                s4_min_t  <= s3_min_t;
                s4_reject <= s3_reject || box_out;
                s4_px     <= px_w;
                s4_py     <= py_w;
                s4_pz     <= pz_w;
            end

            // --- Stage 5 ---
            logic               s5_valid, s5_last;
            logic [5:0]         s5_idx;
            logic signed [31:0] s5_r2;
            logic               s5_diel;
            logic signed [31:0] s5_neg_b, s5_min_t;
            logic               s5_reject;
            logic signed [31:0] s5_px2, s5_py2, s5_pz2;

            wire signed [63:0] prod_px2 = 64'(s4_px) * 64'(s4_px);
            wire signed [63:0] prod_py2 = 64'(s4_py) * 64'(s4_py);
            wire signed [63:0] prod_pz2 = 64'(s4_pz) * 64'(s4_pz);

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin s5_valid <= 1'b0; s5_last <= 1'b0; end
                else        begin s5_valid <= s4_valid; s5_last <= s4_last; end
            end
            always_ff @(posedge clk) begin
                s5_idx    <= s4_idx;
                s5_r2     <= s4_r2;
                s5_diel   <= s4_diel;
                s5_neg_b  <= s4_neg_b;
                s5_min_t  <= s4_min_t;
                s5_reject <= s4_reject;
                s5_px2    <= prod_px2[47:16];
                s5_py2    <= prod_py2[47:16];
                s5_pz2    <= prod_pz2[47:16];
            end

            // --- Stage 6 ---
            logic               s6_valid, s6_last;
            logic [5:0]         s6_idx;
            logic               s6_diel;
            logic signed [31:0] s6_neg_b, s6_min_t;
            logic               s6_reject;
            logic [47:0]        s6_rad;

            wire signed [31:0] perp_len2 = (s5_px2 + s5_py2) + s5_pz2;
            wire signed [31:0] disc_w    = s5_r2 - perp_len2;
            wire               disc_neg  = (disc_w < 32'sd0);

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin s6_valid <= 1'b0; s6_last <= 1'b0; end
                else        begin s6_valid <= s5_valid; s6_last <= s5_last; end
            end
            always_ff @(posedge clk) begin
                s6_idx    <= s5_idx;
                s6_diel   <= s5_diel;
                s6_neg_b  <= s5_neg_b;
                s6_min_t  <= s5_min_t;
                s6_reject <= s5_reject || disc_neg;
                s6_rad    <= (s5_reject || disc_neg) ? 48'd0 : {disc_w[31:0], 16'd0};
            end

            // --- Stage 7..18: 24bit Restoring Square Root (12段) ---
            logic               sq_valid [1:12];
            logic               sq_last  [1:12];
            logic [5:0]         sq_idx   [1:12];
            logic               sq_diel  [1:12];
            logic signed [31:0] sq_neg_b [1:12];
            logic signed [31:0] sq_min_t [1:12];
            logic               sq_reject[1:12];
            logic [47:0]        sq_rad   [1:12];
            logic [27:0]        sq_rem   [1:12];
            logic [23:0]        sq_q     [1:12];

            genvar st;
            for (st = 0; st < 12; st++) begin : gen_sqrt
                logic               in_valid;
                logic               in_last;
                logic [5:0]         in_idx;
                logic               in_diel;
                logic signed [31:0] in_neg_b;
                logic signed [31:0] in_min_t;
                logic               in_reject;
                logic [47:0]        in_rad;
                logic [27:0]        in_rem;
                logic [23:0]        in_q;

                if (st == 0) begin : gen_sq_in0
                    assign in_valid  = s6_valid;
                    assign in_last   = s6_last;
                    assign in_idx    = s6_idx;
                    assign in_diel   = s6_diel;
                    assign in_neg_b  = s6_neg_b;
                    assign in_min_t  = s6_min_t;
                    assign in_reject = s6_reject;
                    assign in_rad    = s6_rad;
                    assign in_rem    = 28'd0;
                    assign in_q      = 24'd0;
                end else begin : gen_sq_inN
                    assign in_valid  = sq_valid[st];
                    assign in_last   = sq_last[st];
                    assign in_idx    = sq_idx[st];
                    assign in_diel   = sq_diel[st];
                    assign in_neg_b  = sq_neg_b[st];
                    assign in_min_t  = sq_min_t[st];
                    assign in_reject = sq_reject[st];
                    assign in_rad    = sq_rad[st];
                    assign in_rem    = sq_rem[st];
                    assign in_q      = sq_q[st];
                end

                logic [27:0] rem1, test1, rem1_next;
                logic [23:0] q1;
                logic [27:0] rem2, test2, rem2_next;
                logic [23:0] q2;

                always_comb begin
                    rem1  = {in_rem[25:0], in_rad[47:46]};
                    test1 = {2'b00, in_q, 2'b01};
                    if (rem1 >= test1) begin
                        rem1_next = rem1 - test1;
                        q1        = {in_q[22:0], 1'b1};
                    end else begin
                        rem1_next = rem1;
                        q1        = {in_q[22:0], 1'b0};
                    end

                    rem2  = {rem1_next[25:0], in_rad[45:44]};
                    test2 = {2'b00, q1, 2'b01};
                    if (rem2 >= test2) begin
                        rem2_next = rem2 - test2;
                        q2        = {q1[22:0], 1'b1};
                    end else begin
                        rem2_next = rem2;
                        q2        = {q1[22:0], 1'b0};
                    end
                end

                always_ff @(posedge clk or negedge rst_n) begin
                    if (!rst_n) begin sq_valid[st+1] <= 1'b0; sq_last[st+1] <= 1'b0; end
                    else        begin sq_valid[st+1] <= in_valid; sq_last[st+1] <= in_last; end
                end
                always_ff @(posedge clk) begin
                    sq_idx[st+1]    <= in_idx;
                    sq_diel[st+1]   <= in_diel;
                    sq_neg_b[st+1]  <= in_neg_b;
                    sq_min_t[st+1]  <= in_min_t;
                    sq_reject[st+1] <= in_reject;
                    sq_rad[st+1]    <= {in_rad[43:0], 4'd0};
                    sq_rem[st+1]    <= rem2_next;
                    sq_q[st+1]      <= q2;
                end
            end

            wire signed [31:0] fin_sqrtd = {8'd0, sq_q[12]};
            wire signed [31:0] r1        = sq_neg_b[12] - fin_sqrtd;
            wire signed [31:0] r2        = sq_neg_b[12] + fin_sqrtd;

            wire cull_d = (sq_min_t[12] >= closest_reg);
            wire r1_ok  = !sq_reject[12] && !cull_d && (r1 > ray_tmin) && (r1 < closest_reg);
            wire r2_ok  = !sq_reject[12] && !cull_d && !r1_ok && sq_diel[12] && (r2 > ray_tmin) && (r2 < closest_reg);

            assign lane_fin_valid[g] = sq_valid[12];
            assign lane_fin_last[g]  = sq_last[12];
            assign lane_hit[g]       = r1_ok || r2_ok;
            assign lane_t[g]         = r1_ok ? r1 : r2;
            assign lane_idx[g]       = sq_idx[12];
        end
    endgenerate

    // =========================================================================
    // 4レーン最小値リダクション木
    // =========================================================================
    logic               w01_hit, w23_hit, wall_hit;
    logic signed [31:0] w01_t,   w23_t,   wall_t;
    logic [5:0]         w01_idx, w23_idx, wall_idx;

    always_comb begin
        if (lane_hit[0] && lane_hit[1]) begin
            if (lane_t[1] < lane_t[0]) begin w01_hit = 1'b1; w01_t = lane_t[1]; w01_idx = lane_idx[1]; end
            else                       begin w01_hit = 1'b1; w01_t = lane_t[0]; w01_idx = lane_idx[0]; end
        end else if (lane_hit[0]) begin w01_hit = 1'b1; w01_t = lane_t[0]; w01_idx = lane_idx[0];
        end else if (lane_hit[1]) begin w01_hit = 1'b1; w01_t = lane_t[1]; w01_idx = lane_idx[1];
        end else                  begin w01_hit = 1'b0; w01_t = 32'h7FFF_0000; w01_idx = 6'd0; end

        if (lane_hit[2] && lane_hit[3]) begin
            if (lane_t[3] < lane_t[2]) begin w23_hit = 1'b1; w23_t = lane_t[3]; w23_idx = lane_idx[3]; end
            else                       begin w23_hit = 1'b1; w23_t = lane_t[2]; w23_idx = lane_idx[2]; end
        end else if (lane_hit[2]) begin w23_hit = 1'b1; w23_t = lane_t[2]; w23_idx = lane_idx[2];
        end else if (lane_hit[3]) begin w23_hit = 1'b1; w23_t = lane_t[3]; w23_idx = lane_idx[3];
        end else                  begin w23_hit = 1'b0; w23_t = 32'h7FFF_0000; w23_idx = 6'd0; end

        if (w01_hit && w23_hit) begin
            if (w23_t < w01_t) begin wall_hit = 1'b1; wall_t = w23_t; wall_idx = w23_idx; end
            else               begin wall_hit = 1'b1; wall_t = w01_t; wall_idx = w01_idx; end
        end else if (w01_hit) begin wall_hit = 1'b1; wall_t = w01_t; wall_idx = w01_idx;
        end else if (w23_hit) begin wall_hit = 1'b1; wall_t = w23_t; wall_idx = w23_idx;
        end else              begin wall_hit = 1'b0; wall_t = 32'h7FFF_0000; wall_idx = 6'd0; end
    end

    // =========================================================================
    // メイン制御 & 結果更新 (Cycle 17で地面、Cycle 18..33で球0..63を更新)
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ray_ox       <= 32'sd0;
            ray_oy       <= 32'sd0;
            ray_oz       <= 32'sd0;
            ray_dx       <= 32'sd0;
            ray_dy       <= 32'sd0;
            ray_dz       <= 32'sd0;
            ray_tmin     <= 32'sd256;
            busy         <= 1'b0;
            batch_idx    <= 5'd16;
            closest_reg  <= 32'h7FFF_0000;
            best_idx_reg <= -32'sd1;
        end else begin
            if (sel && we && !busy && (addr_offset < 12'h100)) begin
                case (addr_offset)
                    12'h000: ray_ox   <= signed'(wdata);
                    12'h004: ray_oy   <= signed'(wdata);
                    12'h008: ray_oz   <= signed'(wdata);
                    12'h00C: ray_dx   <= signed'(wdata);
                    12'h010: ray_dy   <= signed'(wdata);
                    12'h014: ray_dz   <= signed'(wdata);
                    12'h018: ray_tmin <= signed'(wdata);
                    12'h01C: begin
                        closest_reg  <= signed'(wdata);
                        best_idx_reg <= -32'sd1;
                        batch_idx    <= 5'd0;
                        busy         <= 1'b1;
                    end
                    default: ;
                endcase
            end

            if (busy) begin
                if (batch_idx < 5'd16) begin
                    batch_idx <= batch_idx + 5'd1;
                end

                // Cycle 17: 地面の交差判定が完了 (球のBatch 0が到着する1クロック前)
                if (gnd_fin_valid && gnd_hit_ok) begin
                    closest_reg  <= gnd_root;
                    best_idx_reg <= 32'sd64; // NUM_SPHERES = 64
                end

                // Cycle 18..33: 球 0..63 の交差判定結果で更新
                if (lane_fin_valid[0]) begin
                    if (wall_hit && (wall_t < closest_reg)) begin
                        closest_reg  <= wall_t;
                        best_idx_reg <= {26'd0, wall_idx};
                    end
                    if (lane_fin_last[0]) begin
                        busy <= 1'b0;
                    end
                end
            end
        end
    end

endmodule

