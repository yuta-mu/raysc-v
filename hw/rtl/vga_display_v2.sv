// 320x180 VRAM (各色 8bit) + 6倍スケーラー + 6x6 ブロック内ディザ (1920x1080 フルHD出力)
// ディザ: 各色 8bit の値を 0..540 に変換し，閾値 (0..35) を足して 36 で割った値 (0..15) を出力
// 閾値表は 6x6 ブロックごとに縦横へずらす
module vga_display_v2 #(
    parameter VRAM_INIT_FILE = ""
)(
    input  logic        clk_100m_ibuf,
    input  logic        clk_cpu,
    input  logic        rst_n,

    // CPU / MMIO バス書き込み用ポート (0x4000_0000 経由)
    input  logic        vram_we,       // VRAM 書き込み許可
    input  logic [15:0] vram_waddr,    // ピクセルアドレス (0 .. 57599)
    input  logic [23:0] vram_wdata,    // [23:16] = R, [15:8] = G, [7:0] = B (各色 8bit)

    // ステータス
    output logic        clk_locked,    // MMCM ロックステータス

    // Pmod VGA 出力ポート
    output logic [3:0]  vga_r,         // 赤 4bit
    output logic [3:0]  vga_g,         // 緑 4bit
    output logic [3:0]  vga_b,         // 青 4bit
    output logic        vga_hsync,     // 水平同期信号
    output logic        vga_vsync      // 垂直同期信号
);

    // 1. 【MMCM】148.0MHz ドットクロック生成
    logic clk_150m_unbuf;
    logic clk_150m;
    logic mmcm_fb;
    logic mmcm_locked;

    assign clk_locked = mmcm_locked;

`ifndef SIMULATION
    MMCME2_BASE #(
        .BANDWIDTH("OPTIMIZED"),
        .CLKIN1_PERIOD(10.0),      // 入力: 100MHz (10.0ns)
        // MMCM (148MHzに変更): 100MHz * 37.125 / 5 = 742.5MHz (VCO), 742.5 / 5 = 148.5MHz
        .CLKFBOUT_MULT_F(37.125),
        .DIVCLK_DIVIDE(5),
        .CLKOUT0_DIVIDE_F(5.0),
        .STARTUP_WAIT("FALSE")
    ) u_mmcm_150p (
        .CLKOUT0(clk_150m_unbuf),
        .CLKFBOUT(mmcm_fb),
        .CLKFBIN(mmcm_fb),
        .CLKIN1(clk_100m_ibuf),
        .PWRDWN(1'b0),
        .RST(!rst_n),
        .LOCKED(mmcm_locked)
    );

    BUFG u_bufg_150m (
        .I(clk_150m_unbuf),
        .O(clk_150m)
    );
`else
    assign clk_150m    = clk_100m_ibuf;
    assign mmcm_locked = 1'b1;
`endif

    // リセット: ロックするまで保持し、解除は clk_150m に同期
    wire        rst_pix_async_n = rst_n && mmcm_locked;
    logic [1:0] rst_pix_sync;
    logic       rst_pix_n;

    always_ff @(posedge clk_150m or negedge rst_pix_async_n) begin
        if (!rst_pix_async_n) rst_pix_sync <= 2'b00;
        else                  rst_pix_sync <= {rst_pix_sync[0], 1'b1};
    end
    assign rst_pix_n = rst_pix_sync[1];

    // 2. 【FSM, カウンタ】1080p タイミング制御 (148MHz)
    
    // 水平方向 (ドット数)
    localparam logic [11:0] H_TOTAL  = 12'd2200;
    localparam logic [11:0] H_ACTIVE = 12'd1920;    // 有効表示幅
    localparam logic [11:0] H_FP     = 12'd88;      // Front Porch
    localparam logic [11:0] H_SYNC   = 12'd44;      // Sync Pulse

    // 垂直方向 (ライン数)
    localparam logic [10:0] V_TOTAL  = 11'd1125;    // 合計ライン数
    localparam logic [10:0] V_ACTIVE = 11'd1080;    // 有効表示高さ
    localparam logic [10:0] V_FP     = 11'd4;       // Front Porch
    localparam logic [10:0] V_SYNC   = 11'd5;       // Sync Pulse

    logic [11:0] h_cnt; // 0 〜 2199
    logic [10:0] v_cnt; // 0 〜 1124
    logic        video_on;
    logic        hsync_s, vsync_s; // 段 S の同期信号 (出力までパイプラインで遅延)

    // ステータス
    typedef enum logic {
        ST_WAIT_LOCK = 1'b0,
        ST_RUNNING   = 1'b1
    } state_t;

    state_t state;

    always_ff @(posedge clk_150m or negedge rst_pix_n) begin
        if (!rst_pix_n) begin
            state    <= ST_WAIT_LOCK;
            h_cnt    <= '0;
            v_cnt    <= '0;
            hsync_s  <= 1'b0;
            vsync_s  <= 1'b0;
            video_on <= 1'b0;
        end else begin
            case (state)
                ST_WAIT_LOCK: begin
                    if (mmcm_locked) begin
                        state <= ST_RUNNING;
                    end
                    h_cnt <= '0;
                    v_cnt <= '0;
                end

                ST_RUNNING: begin
                    // H カウンタ管理
                    if (h_cnt == H_TOTAL - 1'b1) begin
                        h_cnt <= '0;
                        // V カウンタ管理
                        if (v_cnt == V_TOTAL - 1'b1) begin
                            v_cnt <= '0;
                        end else begin
                            v_cnt <= v_cnt + 1'b1;
                        end
                    end else begin
                        h_cnt <= h_cnt + 1'b1;
                    end

                    // 同期信号生成 (High アクティブ)
                    hsync_s <= (h_cnt >= (H_ACTIVE + H_FP)) && (h_cnt < (H_ACTIVE + H_FP + H_SYNC));
                    vsync_s <= (v_cnt >= (V_ACTIVE + V_FP)) && (v_cnt < (V_ACTIVE + V_FP + V_SYNC));

                    // アクティブ表示領域フラグ
                    video_on  <= (h_cnt < H_ACTIVE) && (v_cnt < V_ACTIVE);
                end
            endcase
        end
    end

    // 3. 6倍スケーラー ＆ 座標算出カウンタ (320x180 -> 1920x1080)
    logic [8:0] vram_x; // 0..319
    logic [7:0] vram_y; // 0..179
    logic [2:0] cnt_x;  // 0..5
    logic [2:0] cnt_y;  // 0..5

    // X方向 6分周
    always_ff @(posedge clk_150m or negedge rst_pix_n) begin
        if (!rst_pix_n) begin
            vram_x <= '0;
            cnt_x  <= '0;
        end else if (state == ST_RUNNING && video_on) begin
            if (cnt_x == 3'd5) begin
                cnt_x  <= 3'd0;
                vram_x <= vram_x + 1'b1;
            end else begin
                cnt_x  <= cnt_x + 1'b1;
            end
        end else begin
            vram_x <= '0;
            cnt_x  <= '0;
        end
    end

    // Y方向 6分周 (各行の終わり h_cnt == 2199 で更新)
    wire line_end = (h_cnt == H_TOTAL - 1'b1);

    always_ff @(posedge clk_150m or negedge rst_pix_n) begin
        if (!rst_pix_n) begin
            vram_y <= '0;
            cnt_y  <= '0;
        end else if (state == ST_RUNNING && line_end) begin
            if (v_cnt < V_ACTIVE) begin
                if (cnt_y == 3'd5) begin
                    cnt_y  <= 3'd0;
                    vram_y <= vram_y + 1'b1;
                end else begin
                    cnt_y  <= cnt_y + 1'b1;
                end
            end else begin
                vram_y <= '0;
                cnt_y  <= '0;
            end
        end
    end

    // 4. VRAM 読み出しアドレス (段 S -> 段 S+1)

    logic [15:0] vram_raddr_reg;

    always_ff @(posedge clk_150m or negedge rst_pix_n) begin
        if (!rst_pix_n) begin
            vram_raddr_reg <= '0;
        end else begin
            // vram_raddr = vram_y * 320 + vram_x (320 = 256 + 64)
            vram_raddr_reg <= {vram_y, 8'b0} + {2'b0, vram_y, 6'b0} + {7'b0, vram_x};
        end
    end

    // 5. Dual Port Block RAM (320x180 VRAM)
    logic [23:0] vram_rdata;

    vram #(
        .WIDTH(320),
        .HEIGHT(180),
        .COLOR_DEPTH(24),
        .INIT_FILE(VRAM_INIT_FILE)
    ) u_vram (
        .clk_cpu (clk_cpu),
        .we      (vram_we),
        .waddr   (vram_waddr),
        .wdata   (vram_wdata),

        .clk_vga (clk_150m),
        .raddr   (vram_raddr_reg),
        .rdata   (vram_rdata)
    );

    // 6. ディザ・パイプライン
    //    段 S+1 : 閾値 thr_q1 (6x6 ブロック内の位置から 0..35)
    //    段 S+2 : rdata 到着
    //    段 S+3 : 8bitを0～540 にスケール変換 (u = (v*2169 + 512) >> 10)
    //    段 S+4 : (u + thr) / 36 = ((u + thr) * 1821) >> 16  を出力 (0..15)
    //    同期信号も 4 段遅らせて、RGB と揃える
    function automatic logic [5:0] thr_f(
        input logic       by0,
        input logic [2:0] cy,
        input logic       bx0,
        input logic [2:0] cx
    );
        begin
            case ({cy, cx})
                // Y = 0
                6'd0:  thr_f = 6'd17;
                6'd1:  thr_f = 6'd3;
                6'd2:  thr_f = 6'd25;
                6'd3:  thr_f = 6'd9;
                6'd4:  thr_f = 6'd31;
                6'd5:  thr_f = 6'd13;

                // Y = 1
                6'd8:  thr_f = 6'd29;
                6'd9:  thr_f = 6'd11;
                6'd10: thr_f = 6'd1;
                6'd11: thr_f = 6'd21;
                6'd12: thr_f = 6'd5;
                6'd13: thr_f = 6'd19;

                // Y = 2
                6'd16: thr_f = 6'd7;
                6'd17: thr_f = 6'd23;
                6'd18: thr_f = 6'd15;
                6'd19: thr_f = 6'd33;
                6'd20: thr_f = 6'd27;
                6'd21: thr_f = 6'd35;

                // Y = 3
                6'd24: thr_f = 6'd20;
                6'd25: thr_f = 6'd6;
                6'd26: thr_f = 6'd30;
                6'd27: thr_f = 6'd12;
                6'd28: thr_f = 6'd24;
                6'd29: thr_f = 6'd0;

                // Y = 4
                6'd32: thr_f = 6'd32;
                6'd33: thr_f = 6'd16;
                6'd34: thr_f = 6'd4;
                6'd35: thr_f = 6'd28;
                6'd36: thr_f = 6'd10;
                6'd37: thr_f = 6'd22;

                // Y = 5
                6'd40: thr_f = 6'd14;
                6'd41: thr_f = 6'd26;
                6'd42: thr_f = 6'd18;
                6'd43: thr_f = 6'd34;
                6'd44: thr_f = 6'd2;
                6'd45: thr_f = 6'd8;

                default: thr_f = 6'd0;
            endcase
        end
    endfunction
    
    function automatic logic [2:0] add6(input logic [2:0] a, input logic [2:0] k);
        logic [3:0] s;
        begin
            s    = {1'b0, a} + {1'b0, k};
            add6 = (s >= 4'd6) ? 3'(s - 4'd6) : s[2:0];
        end
    endfunction

    // ---- ブロックごとの閾値ずらし ---------------------------------------------
    // 6x6 ブロック (= VRAM 1 画素) の位置 (vram_x, vram_y) から、縦横のずらし量 (0..5) を作る。
    // ずらした閾値表も 0..35 を 1 回ずつ使うので、ブロックの平均の明るさは変わらない。
    // 0 にすると、従来どおり (全ブロック同じ並び) になる。
    localparam bit BLOCK_SHIFT_EN = 1'b1;

    // 段 S+1: 17bit の混ぜ合わせ (前半)
    function automatic logic [16:0] hash_a(input logic [8:0] bx, input logic [7:0] by);
        logic [16:0] v;
        begin
            v = {by, bx};
            v = v ^ (v >> 8);
            v = v + (v << 7);
            v = v ^ (v >> 5);
            hash_a = v;
        end
    endfunction

    // 段 S+2: 混ぜ合わせ (後半)。戻り値 = {縦用 6bit, 横用 6bit}
    function automatic logic [11:0] hash_b(input logic [16:0] v0);
        logic [16:0] v;
        begin
            v = v0 + (v0 << 2) + (v0 << 9);
            v = v ^ (v >> 7);
            hash_b = v[11:0];
        end
    endfunction

    function automatic logic [2:0] mod6(input logic [5:0] x);
        begin
            mod6 = 3'(x % 6);
        end
    endfunction

    // --- ここから追加 ---
    `include "thr_alt_f.svh"    // 添付の関数をここに貼る(または include)
    `include "scale_lut.svh"

    logic       z_r, z_g, z_b;                 // 境目の区間のフラグ
    logic [5:0] tha_r_q4, tha_g_q4, tha_b_q4;  // 2画素クラスタ閾値 (段 S+4 で有効)
    // --- ここまで追加 ---
    logic [5:0] thr_r_q4, thr_g_q4, thr_b_q4;  // 通常の閾値 (段 S+4 で有効)

    // ブロックずらし用のレジスタ
    logic [16:0] hash_q1;                      // 段 S+1
    logic [2:0]  cx_q1, cy_q1;
    logic [11:0] hash_q2;                      // 段 S+2
    logic [2:0]  cx_q2, cy_q2;
    logic [2:0]  sy_q3;                        // 段 S+3: 縦ずらし
    logic [2:0]  sxr_q3, sxg_q3, sxb_q3;       //         横ずらし (通常。G, B は列ずらし 5, 4 を合成済み)
    logic [2:0]  sxar_q3, sxag_q3, sxab_q3;    //         横ずらし (2画素クラスタ用。偶数に丸める)
    logic [2:0]  cx_q3, cy_q3;
    logic [2:0]  sx_c, sy_c, sxe_c, cyy_c;     // 組み合わせの途中値 (下の assign)
    assign sx_c  = BLOCK_SHIFT_EN ? mod6(hash_q2[5:0])  : 3'd0;
    assign sy_c  = BLOCK_SHIFT_EN ? mod6(hash_q2[11:6]) : 3'd0;
    assign sxe_c = {sx_c[2:1], 1'b0};          // 2画素クラスタ用: 偶数にそろえる (かたまりを割らない)
    assign cyy_c = add6(cy_q3, sy_q3);
    logic       de_q1, de_q2, de_q3, de_q4;
    logic [23:0] vram_rdata_q;          // BRAM出力を受けるレジスタ
    logic [9:0] u_r, u_g, u_b;          // 0..540

    wire [7:0] v_r = vram_rdata_q[23:16];
    wire [7:0] v_g = vram_rdata_q[15:8];
    wire [7:0] v_b = vram_rdata_q[7:0];

    // (v * 2169 + 512) >> 10 : 最大 255*2169+512 = 553,607 だから 20bit
    function automatic logic [9:0] scale540(input logic [7:0] v);
        logic [19:0] p;
        begin
            p = {12'b0, v} * 20'd2169 + 20'd512;
            scale540 = p[19:10];
        end
    endfunction

    logic [9:0] s_r, s_g, s_b;   // u + t
    logic       de_q5;
    logic [5:0] hs_d, vs_d;

    function automatic logic [3:0] div36(input logic [9:0] s);
        logic [20:0] p;
        begin
            p = s * 21'd1821;
            div36 = p[19:16];
        end
    endfunction

always_ff @(posedge clk_150m) begin
    // 段 S+1: ブロック位置のハッシュ (前半) と、ブロック内の位置の遅延
    hash_q1 <= hash_a(vram_x, vram_y);
    cx_q1   <= cnt_x;
    cy_q1   <= cnt_y;
    de_q1   <= video_on;

    // 段 S+2: ハッシュ (後半)
    hash_q2 <= hash_b(hash_q1);
    cx_q2   <= cx_q1;
    cy_q2   <= cy_q1;
    de_q2   <= de_q1;

    // 段 S+3: ずらし量 (0..5) に変換し、色ごとの列ずらし (G=5, B=4) を合成
    sy_q3   <= sy_c;
    sxr_q3  <= sx_c;
    sxg_q3  <= add6(sx_c, 3'd5);
    sxb_q3  <= add6(sx_c, 3'd4);
    sxar_q3 <= sxe_c;
    sxag_q3 <= add6(sxe_c, 3'd5);
    sxab_q3 <= add6(sxe_c, 3'd4);
    cx_q3   <= cx_q2;
    cy_q3   <= cy_q2;
    de_q3   <= de_q2;
    vram_rdata_q <= vram_rdata;

    // 段 S+4: 閾値の参照 (通常 / 2画素クラスタ)
    thr_r_q4 <= thr_f(1'b0, cyy_c, 1'b0, add6(cx_q3, sxr_q3));
    thr_g_q4 <= thr_f(1'b0, cyy_c, 1'b0, add6(cx_q3, sxg_q3));
    thr_b_q4 <= thr_f(1'b0, cyy_c, 1'b0, add6(cx_q3, sxb_q3));
    tha_r_q4 <= thr_alt_f(cyy_c, add6(cx_q3, sxar_q3));
    tha_g_q4 <= thr_alt_f(cyy_c, add6(cx_q3, sxag_q3));
    tha_b_q4 <= thr_alt_f(cyy_c, add6(cx_q3, sxab_q3));
    de_q4    <= de_q3;
    {z_r, u_r} <= scale_lut_r_f(v_r);
    {z_g, u_g} <= scale_lut_g_f(v_g);
    {z_b, u_b} <= scale_lut_b_f(v_b);

    // 段 S+5: 加算．閾値をフラグで切り替え
    s_r <= u_r + {4'b0, z_r ? tha_r_q4 : thr_r_q4};
    s_g <= u_g + {4'b0, z_g ? tha_g_q4 : thr_g_q4};
    s_b <= u_b + {4'b0, z_b ? tha_b_q4 : thr_b_q4};
    de_q5 <= de_q4;

    // 段 S+6: 乗算と出力
    vga_r <= de_q5 ? div36(s_r) : 4'h0;
    vga_g <= de_q5 ? div36(s_g) : 4'h0;
    vga_b <= de_q5 ? div36(s_b) : 4'h0;

    // 同期信号 (段 S -> 段 S+6)
    hs_d <= {hs_d[4:0], hsync_s};
    vs_d <= {vs_d[4:0], vsync_s};
end

assign vga_hsync = hs_d[5];
assign vga_vsync = vs_d[5];

endmodule
