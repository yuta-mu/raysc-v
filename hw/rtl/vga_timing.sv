// 概要         : VGA 640x480 @ 60Hz タイミング信号および画面座標生成回路
module vga_timing (
    input  logic       clk,      // クロック (50MHz)
    input  logic       rst_n,

    output logic       hsync,    // 水平同期信号 (Low アクティブ)
    output logic       vsync,    // 垂直同期信号 (Low アクティブ)
    output logic       video_on, // 1: 画面内表示, 0: ブランキング
    output logic [9:0] pixel_x,  // 現在の X 座標 (0 〜 639)
    output logic [9:0] pixel_y   // 現在の Y 座標 (0 〜 479)
);

    // 水平方向 (ドット数)
    localparam H_ACTIVE = 640; // 有効表示幅
    localparam H_FRONT  = 16;  // Front Porch
    localparam H_SYNC   = 96;  // Sync Pulse
    localparam H_BACK   = 48;  // Back Porch
    localparam H_TOTAL  = 800; // 合計ドット幅

    // 垂直方向 (ライン数)
    localparam V_ACTIVE = 480; // 有効表示高さ
    localparam V_FRONT  = 10;  // Front Porch
    localparam V_SYNC   = 2;   // Sync Pulse
    localparam V_BACK   = 33;  // Back Porch
    localparam V_TOTAL  = 525; // 合計ライン数

    // クロック生成 (clkの立ち上がりでclk_25を反転)
    logic clk_25m;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            clk_25m <= 1'b0;
        else
            clk_25m <= ~clk_25m;
    end

    logic [9:0] h_cnt; // 0 〜 799
    logic [9:0] v_cnt; // 0 〜 524

    // 水平カウンタ (25MHz クロックでインクリメント)
    always_ff @(posedge clk or negedge rst_n) begin //clk_25mだとずれるのかな？
        if (!rst_n) begin
            h_cnt <= '0;
        end else if (clk_25m) begin
            if (h_cnt == H_TOTAL - 1)
                h_cnt <= '0;
            else
                h_cnt <= h_cnt + 1'b1;
        end
    end

    // 垂直カウンタ (1行分が終わるごとにインクリメント)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v_cnt <= '0;
        end else if (clk_25m && (h_cnt == H_TOTAL - 1)) begin
            if (v_cnt == V_TOTAL - 1)
                v_cnt <= '0;
            else
                v_cnt <= v_cnt + 1'b1;
        end
    end

    // 同期信号 (hsync / vsync) の生成
    // h_cnt が 656 〜 751 の間 Low
    assign hsync = ~((h_cnt >= (H_ACTIVE + H_FRONT)) && (h_cnt <  (H_ACTIVE + H_FRONT + H_SYNC)));

    // v_cnt が 490 〜 491 の間 Low
    assign vsync = ~((v_cnt >= (V_ACTIVE + V_FRONT)) && (v_cnt <  (V_ACTIVE + V_FRONT + V_SYNC)));

    // 有効表示フラグおよび座標出力の設定
    assign video_on = (h_cnt < H_ACTIVE) && (v_cnt < V_ACTIVE);
    assign pixel_x  = video_on ? h_cnt : 10'd0;
    assign pixel_y  = video_on ? v_cnt : 10'd0;

endmodule