// フルHD (1920x1080 @ 60Hz) タイミング信号
module vga_timing_1080p (
    input  logic        clk_148_5m, // ピクセルクロック (148.5MHz)
    input  logic        rst_n,

    output logic        hsync,      // 水平同期信号 (High アクティブ)
    output logic        vsync,      // 垂直同期信号 (High アクティブ)
    output logic        video_on,   // 1: 表示領域 (1920x1080), 0: ブランキング期間
    output logic [11:0] pixel_x,    // 現在の X 座標 (0 〜 1919)
    output logic [10:0] pixel_y,    // 現在の Y 座標 (0 〜 1079)
    output logic [11:0] h_cnt_out   // デバッグ・タイマ制御用 Hカウンタ (0 〜 2199)
);

    // 1080p @ 60Hz タイミングパラメータ (CEA-861)
    // 水平方向 (ドット数)
    localparam H_ACTIVE = 1920; // 有効表示幅
    localparam H_FRONT  = 88;   // Front Porch
    localparam H_SYNC   = 44;   // Sync Pulse
    localparam H_BACK   = 148;  // Back Porch
    localparam H_TOTAL  = 2200; // 合計ドット幅

    // 垂直方向 (ライン数)
    localparam V_ACTIVE = 1080; // 有効表示高さ
    localparam V_FRONT  = 4;    // Front Porch
    localparam V_SYNC   = 5;    // Sync Pulse
    localparam V_BACK   = 36;   // Back Porch
    localparam V_TOTAL  = 1125; // 合計ライン数

    logic [11:0] h_cnt; // 0 〜 2199
    logic [10:0] v_cnt; // 0 〜 1124

    assign h_cnt_out = h_cnt;

    // 水平カウンタ (148.5MHz クロックでインクリメント)
    always_ff @(posedge clk_148_5m or negedge rst_n) begin
        if (!rst_n) begin
            h_cnt <= 12'd0;
        end else begin
            if (h_cnt == H_TOTAL - 1)
                h_cnt <= 12'd0;
            else
                h_cnt <= h_cnt + 1'b1;
        end
    end

    // 垂直カウンタ (1行終了ごとにインクリメント)
    always_ff @(posedge clk_148_5m or negedge rst_n) begin
        if (!rst_n) begin
            v_cnt <= 11'd0;
        end else if (h_cnt == H_TOTAL - 1) begin
            if (v_cnt == V_TOTAL - 1)
                v_cnt <= 11'd0;
            else
                v_cnt <= v_cnt + 1'b1;
        end
    end

    // 同期信号 (hsync, vsync) の生成
    // h_cnt が 2008 から 2051 の範囲で hsync を High にする
    assign hsync = (h_cnt >= (H_ACTIVE + H_FRONT)) && (h_cnt < (H_ACTIVE + H_FRONT + H_SYNC));

    // v_cnt が 1084 から 1088 の範囲で vsync を High にする
    assign vsync = (v_cnt >= (V_ACTIVE + V_FRONT)) && (v_cnt < (V_ACTIVE + V_FRONT + V_SYNC));

    // 有効表示領域フラグおよび座標出力
    assign video_on = (h_cnt < H_ACTIVE) && (v_cnt < V_ACTIVE);
    assign pixel_x  = video_on ? h_cnt : 12'd0;
    assign pixel_y  = video_on ? v_cnt : 11'd0;

endmodule
