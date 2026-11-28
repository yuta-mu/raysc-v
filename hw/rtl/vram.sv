// 320x180 Dual Port Block RAM
module vram #(
    parameter int WIDTH       = 320,
    parameter int HEIGHT      = 180,
    parameter int COLOR_DEPTH = 24, // 24-bit RGB888 ([23:16]=R, [15:8]=G, [7:0]=B)
    parameter     INIT_FILE = ""
)(
    // Port A: CPU 書き込みポート
    input  logic                   clk_cpu,
    input  logic                   we,
    input  logic [15:0]            waddr, // 0 ～ 57599 (320 × 180 - 1)
    input  logic [COLOR_DEPTH-1:0] wdata, // [23:16]=R, [15:8]=G, [7:0]=B (RGB888)

    // Port B: VGA 読み出しポート
    input  logic                   clk_vga,
    input  logic [15:0]            raddr,
    output logic [COLOR_DEPTH-1:0] rdata
);

    localparam int NUM_PIXELS = WIDTH * HEIGHT; // 57,600 ピクセル

    (* ram_style = "block", cascade_height = 1 *)
    logic [COLOR_DEPTH-1:0] mem [0:NUM_PIXELS-1];

        // 初期化: 先にゼロクリアしてから画像を読み込む
    initial begin
        for (int i = 0; i < NUM_PIXELS; i++) mem[i] = '0;
        if (INIT_FILE != "" && INIT_FILE != "NONE") $readmemh(INIT_FILE, mem);
    end

    // Port A: 書き込み (CPUクロック同期)
    always_ff @(posedge clk_cpu) begin
        if (we) begin
            mem[waddr] <= wdata;
        end
    end

    // Port B: 読み出し (VGAクロック同期)
    always_ff @(posedge clk_vga) begin
        rdata <= mem[raddr];
    end

endmodule
