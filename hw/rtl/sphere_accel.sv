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
    localparam logic signed [31:0] INIT_X_ROUND [0:63] = '{
        32'sd0,       -32'sd262144,  32'sd262144, -32'sd372244,  32'sd449577, -32'sd517734,  32'sd405668, -32'sd532808,
       -32'sd231997,   32'sd493486, -32'sd394527,  32'sd96993,  -32'sd28836,   32'sd513802,  32'sd521667, -32'sd469893,
       -32'sd229376,  -32'sd323748,  32'sd374211, -32'sd494797, -32'sd308019,  32'sd216924,  32'sd463340,  32'sd70779,
        32'sd532808,   32'sd332923, -32'sd125829, -32'sd513147,  32'sd287048, -32'sd66847,   32'sd549192,  32'sd403046,
       -32'sd380109,  -32'sd11141,  -32'sd268698,  32'sd66191,   32'sd39977,  -32'sd93716,  -32'sd251003,  32'sd394527,
        32'sd154665,   32'sd270664, -32'sd134349,  32'sd589824,  32'sd126484, -32'sd148111, -32'sd293601, -32'sd73400,
        32'sd227410,  -32'sd135004, -32'sd351928,  32'sd430572,  32'sd585892,  32'sd338166,  32'sd472515, -32'sd445645,
        32'sd62259,   -32'sd166461, -32'sd403702, -32'sd551813,  32'sd490209, -32'sd502661,  32'sd22938,  -32'sd475791
    };

    localparam logic signed [31:0] INIT_X_TRUNC [0:63] = '{
        32'sd0,       -32'sd262144,  32'sd262144, -32'sd372244,  32'sd449576, -32'sd517734,  32'sd405667, -32'sd532807,
       -32'sd231997,   32'sd493486, -32'sd394526,  32'sd96993,  -32'sd28835,   32'sd513802,  32'sd521666, -32'sd469893,
       -32'sd229376,  -32'sd323747,  32'sd374210, -32'sd494796, -32'sd308019,  32'sd216924,  32'sd463339,  32'sd70778,
        32'sd532807,   32'sd332922, -32'sd125829, -32'sd513146,  32'sd287047, -32'sd66846,   32'sd549191,  32'sd403046,
       -32'sd380108,  -32'sd11141,  -32'sd268697,  32'sd66191,   32'sd39976,  -32'sd93716,  -32'sd251002,  32'sd394526,
        32'sd154664,   32'sd270663, -32'sd134348,  32'sd589824,  32'sd126484, -32'sd148111, -32'sd293601, -32'sd73400,
        32'sd227409,  -32'sd135004, -32'sd351928,  32'sd430571,  32'sd585891,  32'sd338165,  32'sd472514, -32'sd445644,
        32'sd62259,   -32'sd166461, -32'sd403701, -32'sd551813,  32'sd490209, -32'sd502661,  32'sd22937,  -32'sd475791
    };

    localparam logic signed [31:0] INIT_Z_ROUND [0:63] = '{
        32'sd0,        32'sd0,       32'sd0,      -32'sd243794,  32'sd220856, -32'sd32113,  -32'sd2621,   -32'sd137626,
        32'sd112067,   32'sd115999,  32'sd43254,   32'sd101581,  32'sd140902, -32'sd19005,   32'sd74056,   32'sd146145,
        32'sd201196,  -32'sd89784,   32'sd96993,   32'sd61604,   32'sd81920,  -32'sd67502,  -32'sd237240, -32'sd74056,
       -32'sd199229,   32'sd39977,  -32'sd28180,   32'sd190710,  32'sd112722,  32'sd178258,  32'sd165151, -32'sd68157,
        32'sd110100,  -32'sd98304,  -32'sd214303, -32'sd175636,  32'sd176292,  32'sd25559,  -32'sd129106,  32'sd246415,
       -32'sd27525,   -32'sd139592,  32'sd230687, -32'sd221512,  32'sd201196, -32'sd173015,  32'sd234619,  32'sd109445,
        32'sd191365,   32'sd178913, -32'sd145490,  32'sd125174,  32'sd47841,  -32'sd38666,   32'sd165151, -32'sd76677,
       -32'sd226099,   32'sd0,      -32'sd22938,  -32'sd211026, -32'sd144835, -32'sd197263,  32'sd243139, -32'sd142868
    };

    localparam logic signed [31:0] INIT_Z_TRUNC [0:63] = '{
        32'sd0,        32'sd0,       32'sd0,      -32'sd243793,  32'sd220856, -32'sd32112,  -32'sd2621,   -32'sd137625,
        32'sd112066,   32'sd115998,  32'sd43253,   32'sd101580,  32'sd140902, -32'sd19005,   32'sd74055,   32'sd146145,
        32'sd201195,  -32'sd89784,   32'sd96993,   32'sd61603,   32'sd81920,  -32'sd67502,  -32'sd237240, -32'sd74055,
       -32'sd199229,   32'sd39976,  -32'sd28180,   32'sd190709,  32'sd112721,  32'sd178257,  32'sd165150, -32'sd68157,
        32'sd110100,  -32'sd98304,  -32'sd214302, -32'sd175636,  32'sd176291,  32'sd25559,  -32'sd129105,  32'sd246415,
       -32'sd27525,   -32'sd139591,  32'sd230686, -32'sd221511,  32'sd201195, -32'sd173015,  32'sd234618,  32'sd109445,
        32'sd191365,   32'sd178913, -32'sd145489,  32'sd125173,  32'sd47841,  -32'sd38666,   32'sd165150, -32'sd76677,
       -32'sd226099,   32'sd0,      -32'sd22937,  -32'sd211025, -32'sd144834, -32'sd197263,  32'sd243138, -32'sd142868
    };

    localparam logic [0:63] INIT_DIEL = 64'b1001_0010_0001_1001_0000_0010_0000_0000_0000_0010_0000_0000_0001_0000_0000_0100;

    logic signed [31:0] sph_x   [0:NUM_LANES-1][0:NUM_BATCH-1];
    logic signed [31:0] sph_y   [0:NUM_LANES-1][0:NUM_BATCH-1];
    logic signed [31:0] sph_z   [0:NUM_LANES-1][0:NUM_BATCH-1];
    logic signed [31:0] sph_r   [0:NUM_LANES-1][0:NUM_BATCH-1];
    logic signed [31:0] sph_r2  [0:NUM_LANES-1][0:NUM_BATCH-1];
    logic               sph_diel[0:NUM_LANES-1][0:NUM_BATCH-1];

    initial begin
        for (int i = 0; i < 64; i++) begin
            automatic int ln = i % 4;
            automatic int bt = i / 4;
            sph_x[ln][bt]    = USE_ROUND ? INIT_X_ROUND[i] : INIT_X_TRUNC[i];
            sph_y[ln][bt]    = (i < 3) ? 32'sd65536 : 32'sd13107;
            sph_z[ln][bt]    = USE_ROUND ? INIT_Z_ROUND[i] : INIT_Z_TRUNC[i];
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
    logic               gsq_valid [0:12];
    logic               gsq_rej   [0:12];
    logic signed [31:0] gsq_neg_b [0:12];
    logic [47:0]        gsq_rad   [0:12];
    logic [27:0]        gsq_rem   [0:12];
    logic [23:0]        gsq_q     [0:12];

    assign gsq_valid[0] = g4_valid;
    assign gsq_rej[0]   = g4_rej;
    assign gsq_neg_b[0] = g4_neg_bs;
    assign gsq_rad[0]   = g4_rad;
    assign gsq_rem[0]   = 28'd0;
    assign gsq_q[0]     = 24'd0;

    genvar gst;
    generate
        for (gst = 0; gst < 12; gst++) begin : gen_gnd_sqrt
            logic [27:0] rem1, test1, rem1_next;
            logic [23:0] q1;
            logic [27:0] rem2, test2, rem2_next;
            logic [23:0] q2;

            always_comb begin
                rem1  = {gsq_rem[gst][25:0], gsq_rad[gst][47:46]};
                test1 = {2'b00, gsq_q[gst], 2'b01};
                if (rem1 >= test1) begin
                    rem1_next = rem1 - test1;
                    q1        = {gsq_q[gst][22:0], 1'b1};
                end else begin
                    rem1_next = rem1;
                    q1        = {gsq_q[gst][22:0], 1'b0};
                end

                rem2  = {rem1_next[25:0], gsq_rad[gst][45:44]};
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
                else        gsq_valid[gst+1] <= gsq_valid[gst];
            end
            always_ff @(posedge clk) begin
                gsq_rej[gst+1]   <= gsq_rej[gst];
                gsq_neg_b[gst+1] <= gsq_neg_b[gst];
                gsq_rad[gst+1]   <= {gsq_rad[gst][43:0], 4'd0};
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
            logic               sq_valid [0:12];
            logic               sq_last  [0:12];
            logic [5:0]         sq_idx   [0:12];
            logic               sq_diel  [0:12];
            logic signed [31:0] sq_neg_b [0:12];
            logic signed [31:0] sq_min_t [0:12];
            logic               sq_reject[0:12];
            logic [47:0]        sq_rad   [0:12];
            logic [27:0]        sq_rem   [0:12];
            logic [23:0]        sq_q     [0:12];

            assign sq_valid[0]  = s6_valid;
            assign sq_last[0]   = s6_last;
            assign sq_idx[0]    = s6_idx;
            assign sq_diel[0]   = s6_diel;
            assign sq_neg_b[0]  = s6_neg_b;
            assign sq_min_t[0]  = s6_min_t;
            assign sq_reject[0] = s6_reject;
            assign sq_rad[0]    = s6_rad;
            assign sq_rem[0]    = 28'd0;
            assign sq_q[0]      = 24'd0;

            genvar st;
            for (st = 0; st < 12; st++) begin : gen_sqrt
                logic [27:0] rem1, test1, rem1_next;
                logic [23:0] q1;
                logic [27:0] rem2, test2, rem2_next;
                logic [23:0] q2;

                always_comb begin
                    rem1  = {sq_rem[st][25:0], sq_rad[st][47:46]};
                    test1 = {2'b00, sq_q[st], 2'b01};
                    if (rem1 >= test1) begin
                        rem1_next = rem1 - test1;
                        q1        = {sq_q[st][22:0], 1'b1};
                    end else begin
                        rem1_next = rem1;
                        q1        = {sq_q[st][22:0], 1'b0};
                    end

                    rem2  = {rem1_next[25:0], sq_rad[st][45:44]};
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
                    else        begin sq_valid[st+1] <= sq_valid[st]; sq_last[st+1] <= sq_last[st]; end
                end
                always_ff @(posedge clk) begin
                    sq_idx[st+1]    <= sq_idx[st];
                    sq_diel[st+1]   <= sq_diel[st];
                    sq_neg_b[st+1]  <= sq_neg_b[st];
                    sq_min_t[st+1]  <= sq_min_t[st];
                    sq_reject[st+1] <= sq_reject[st];
                    sq_rad[st+1]    <= {sq_rad[st][43:0], 4'd0};
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

