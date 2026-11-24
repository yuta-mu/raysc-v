// 320x180 VRAM + 6倍スケーラー (1920x1080 フルHD出力) 統合表示モジュール
module vga_display_1080p (
    input  logic        CLK100MHZ,
    input  logic        rst_n,

    // CPU / MMIO バス書き込み用ポート (0x4000_0000 経由)
    input  logic        vram_we,   // VRAM 書き込み許可
    input  logic [15:0] vram_waddr,// ピクセルアドレス (0 ～ 57599)
    input  logic [11:0] vram_wdata,// [11:0] = B, [7:4] = G, [11:8] = R (各色 4bit)

    // ステータス
    output logic        clk_locked,// MMCM ロックステータス

    // Pmod VGA 出力ポート
    output logic [3:0]  vga_r,     // 赤 4bit
    output logic [3:0]  vga_g,     // 緑 4bit
    output logic [3:0]  vga_b,     // 青 4bit
    output logic        vga_hsync, // 水平同期信号
    output logic        vga_vsync  // 垂直同期信号
);

    // 1. MMCM による 148.5MHz フルHDドットクロック生成
    //    100MHz -> VCO = 100 * 59.4 / 5 = 1188MHz -> 1188 / 8 = 148.5MHz
    logic clk_148_5m_unbuf;
    logic clk_148_5m;
    logic mmcm_fb;
    logic mmcm_locked;

    assign clk_locked = mmcm_locked;

`ifndef SIMULATION
    MMCME2_BASE #(
        .BANDWIDTH("OPTIMIZED"),
        .CLKIN1_PERIOD(10.0),      // 入力 100MHz (10.0ns)
        .CLKFBOUT_MULT_F(59.4),    // 発振器（VCO）の動作可能範囲に収める
        .DIVCLK_DIVIDE(5),         // 位相比較器（PFD）の動作可能範囲に収める
        .CLKOUT0_DIVIDE_F(8.0),    // 実用周波数への引き下げ
        .STARTUP_WAIT("FALSE")     // クロックがロックするまで FPGA 全体の起動を待たない
    ) u_mmcm_1080p (
        .CLKOUT0(clk_148_5m_unbuf),
        .CLKFBOUT(mmcm_fb),
        .CLKFBIN(mmcm_fb),
        .CLKIN1(CLK100MHZ),
        .PWRDWN(1'b0),
        .RST(!rst_n),
        .LOCKED(mmcm_locked)
    );

    BUFG u_bufg_148m (
        .I(clk_148_5m_unbuf),
        .O(clk_148_5m)
    );
`else
    // テストベンチ用クロック直結擬似モデル
    assign clk_148_5m  = CLK100MHZ;
    assign mmcm_locked = 1'b1;
`endif

    // 2. 1080p60 タイミング生成モジュール
    logic        video_on;
    logic [11:0] pixel_x;
    logic [10:0] pixel_y;
    logic [11:0] h_cnt;

    vga_timing_1080p u_vga_timing_1080p (
        .clk_148_5m (clk_148_5m),
        .rst_n      (rst_n && mmcm_locked),
        .hsync      (vga_hsync),
        .vsync      (vga_vsync),
        .video_on   (video_on),
        .pixel_x    (pixel_x),
        .pixel_y    (pixel_y),
        .h_cnt_out  (h_cnt)
    );

    // 6倍スケーラー (320x180 -> 1920x1080)
    // 6分周カウンタ方式（6回分同じ色）
    logic [8:0] vram_x; // 0～319
    logic [7:0] vram_y; // 0～179
    logic [2:0] cnt_x;  // 0～5
    logic [2:0] cnt_y;  // 0～5

    // X方向 6分周
    always_ff @(posedge clk_148_5m or negedge rst_n) begin
        if (!rst_n) begin
            vram_x <= 9'd0;
            cnt_x  <= 3'd0;
        end else if (video_on) begin
            if (cnt_x == 3'd5) begin
                cnt_x  <= 3'd0;
                vram_x <= vram_x + 1'b1;
            end else begin
                cnt_x  <= cnt_x + 1'b1;
            end
        end else begin
            vram_x <= 9'd0;
            cnt_x  <= 3'd0;
        end
    end

    // Y方向 6分周 (各行の終わり h_cnt == 2199 で更新)
    wire line_end = (h_cnt == 12'd2199);

    always_ff @(posedge clk_148_5m or negedge rst_n) begin
        if (!rst_n) begin
            vram_y <= 8'd0;
            cnt_y  <= 3'd0;
        end else if (line_end) begin
            if (pixel_y < 11'd1080) begin
                if (cnt_y == 3'd5) begin
                    cnt_y  <= 3'd0;
                    vram_y <= vram_y + 1'b1;
                end else begin
                    cnt_y  <= cnt_y + 1'b1;
                end
            end else begin
                vram_y <= 8'd0;
                cnt_y  <= 3'd0;
            end
        end
    end

    // vram_raddr = vram_y * 320 + vram_x (320 = 2^8 + 2^6 を利用)
    wire [15:0] vram_raddr = {vram_y, 8'b0} + {2'b0, vram_y, 6'b0} + {7'b0, vram_x};

    // Dual Port BRAM (320x180 VRAM)
    logic [11:0] vram_rdata;

    vram #(
        .WIDTH(320),
        .HEIGHT(180),
        .COLOR_DEPTH(12)
    ) u_vram (
        .clk_cpu (CLK100MHZ),
        .we      (vram_we),
        .waddr   (vram_waddr),
        .wdata   (vram_wdata),

        .clk_vga (clk_148_5m),
        .raddr   (vram_raddr),
        .rdata   (vram_rdata)
    );

    // RGB 出力 (Block RAM の 1サイクル読み出し遅延を吸収)
    logic video_on_d;

    always_ff @(posedge clk_148_5m or negedge rst_n) begin
        if (!rst_n) begin
            video_on_d <= 1'b0;
        end else begin
            video_on_d <= video_on;
        end
    end

    always_comb begin
        if (video_on_d) begin
            vga_r = vram_rdata[11:8];
            vga_g = vram_rdata[7:4];
            vga_b = vram_rdata[3:0];
        end else begin
            vga_r = 4'h0;
            vga_g = 4'h0;
            vga_b = 4'h0;
        end
    end

endmodule
