// 320x180 Dual Port Block RAM
module vram #(
    parameter int WIDTH       = 320,
    parameter int HEIGHT      = 180,
    parameter int COLOR_DEPTH = 12 // 12-bit (R4, G4, B4)
)(
    // Port A: CPU 書き込みポート
    input  logic                   clk_cpu,
    input  logic                   we,
    input  logic [15:0]            waddr, // 0 ～ 57599 (320 × 180 - 1)
    input  logic [COLOR_DEPTH-1:0] wdata, // R4, G4, B4 (12bit)

    // Port B: VGA 読み出しポート
    input  logic                   clk_vga,
    input  logic [15:0]            raddr,
    output logic [COLOR_DEPTH-1:0] rdata
);

    localparam int NUM_PIXELS = WIDTH * HEIGHT; // 57,600 ピクセル

    (* ram_style = "block" *)
    logic [COLOR_DEPTH-1:0] mem [0:NUM_PIXELS-1];

    // 黒で初期化
    initial begin
        for (int i = 0; i < NUM_PIXELS; i++) begin
            mem[i] = '0;
        end
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
