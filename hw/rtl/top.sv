module top (
    input  logic       CLK100MHZ, // Arty A7 100MHz 水晶発振器 (Pin E3)
    input  logic       ck_rst,    // RESET ボタン (Pin C2, Active-Low)
    output logic       uart_tx,   // FTDI USB-UART TX ピン (Pin D10)
    output logic [3:0] led        // ステータス確認用 LED (Pin H5, J5, T9, T10)
);

    // 入力バッファ
    logic clk_100m_ibuf;
    IBUF u_ibuf_clk (
        .I(CLK100MHZ),
        .O(clk_100m_ibuf)
    );

    logic ck_rst_ibuf;
    IBUF u_ibuf_rst (
        .I(ck_rst),
        .O(ck_rst_ibuf)
    );

    // クロック生成
    logic clk_fb;
    logic clk_50m_unbuf;
    logic clk;
    logic pll_locked;

    PLLE2_BASE #(
        .BANDWIDTH("OPTIMIZED"),
        .CLKFBOUT_MULT(8),        // 100MHz * 8 = 800MHz (VCO 動作範囲: 800-1600MHz)
        .CLKFBOUT_PHASE(0.0),
        .CLKIN1_PERIOD(10.0),     // 入力 100MHz (10.0ns)
        .CLKOUT0_DIVIDE(16),      // 800MHz / 16 = 50MHz 出力
        .CLKOUT0_DUTY_CYCLE(0.5),
        .CLKOUT0_PHASE(0.0),
        .DIVCLK_DIVIDE(1),
        .REF_JITTER1(0.01),
        .STARTUP_WAIT("FALSE")
    ) u_pll (
        .CLKOUT0 (clk_50m_unbuf),
        .CLKOUT1 (),
        .CLKOUT2 (),
        .CLKOUT3 (),
        .CLKOUT4 (),
        .CLKOUT5 (),
        .CLKFBOUT(clk_fb),
        .CLKFBIN (clk_fb),
        .CLKIN1  (clk_100m_ibuf),
        .PWRDWN  (1'b0),
        .RST     (!ck_rst_ibuf),   // IBUF 出力を使用
        .LOCKED  (pll_locked)
    );

    // 50MHz 出力をグローバルクロックバッファ経由でシステムへ供給
    BUFG u_bufg (
        .I(clk_50m_unbuf),
        .O(clk)
    );

    // リセット同期化回路
    logic rst_sync_0, rst_n;
    wire sys_rst_assert = !ck_rst_ibuf || !pll_locked; // IBUF 出力を使用

    always_ff @(posedge clk or posedge sys_rst_assert) begin
        if (sys_rst_assert) begin
            rst_sync_0 <= 1'b0;
            rst_n      <= 1'b0;
        end else begin
            rst_sync_0 <= 1'b1;
            rst_n      <= rst_sync_0;
        end
    end

    // SoC バス・周辺回路
    localparam logic [31:0] MEM_BYTES     = 32'h0004_0000; // 256 KB
    localparam logic [31:0] UART_ADDR     = 32'h1000_0000;
    localparam logic [31:0] CYCLE_ADDR    = 32'h2000_0000;
    localparam logic [31:0] INSTRET_ADDR  = 32'h2000_0004;
    localparam logic [31:0] CYCLEH_ADDR   = 32'h2000_0008;
    localparam logic [31:0] INSTRETH_ADDR = 32'h2000_000C;

    logic [31:0] pc, inst;
    logic        mem_read, mem_write;
    logic [31:0] mem_addr, mem_wdata, mem_rdata;
    logic [3:0]  mem_wstrb;
    logic        uart_stall;
    logic        halted;
    logic [63:0] cycles;
    logic [63:0] instret;
    logic        retire;

    cpu u_cpu (.*);

    logic [31:0] bram_rdata;
    wire is_bram = (mem_addr < MEM_BYTES);

    bram #(
        .MEM_WORDS(65536)
    ) u_bram (
        .clk     (clk),
        .a_addr  (pc),
        .a_rdata (inst),
        .b_en    ((mem_read || mem_write) && is_bram),
        .b_we    (mem_write && is_bram),
        .b_wstrb (mem_wstrb),
        .b_addr  (mem_addr),
        .b_wdata (mem_wdata),
        .b_rdata (bram_rdata)
    );

    wire is_uart = (mem_addr == UART_ADDR);

    uart_tx_fifo #(
        .CLK_FREQ   (50_000_000),
        .BAUD_RATE  (115_200),
        .FIFO_DEPTH (512)
    ) u_uart (
        .clk        (clk),
        .rst_n      (rst_n),
        .uart_write (mem_write && is_uart),
        .uart_wdata (mem_wdata[7:0]),
        .uart_stall (uart_stall),
        .uart_tx    (uart_tx)
    );

    logic [31:0] mem_addr_d;
    logic        mem_read_d;
    logic [31:0] mmio_rdata_d;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_addr_d   <= '0;
            mem_read_d   <= 1'b0;
            mmio_rdata_d <= '0;
        end else begin
            mem_addr_d    <= mem_addr;
            mem_read_d    <= mem_read;
            case (mem_addr)
                CYCLE_ADDR:    mmio_rdata_d <= cycles[31:0];
                INSTRET_ADDR:  mmio_rdata_d <= instret[31:0];
                CYCLEH_ADDR:   mmio_rdata_d <= cycles[63:32];
                INSTRETH_ADDR: mmio_rdata_d <= instret[63:32];
                default:       mmio_rdata_d <= 32'h0;
            endcase
        end
    end

    assign mem_rdata = !mem_read_d              ? 32'h0 :
                       (mem_addr_d < MEM_BYTES) ? bram_rdata : mmio_rdata_d;

    assign led[0] = halted;     // ebreak 等で正常停止したら点灯 (LED0: H5)
    assign led[1] = uart_stall; // FIFO が満杯になったら点灯 (LED1: J5)
    assign led[2] = retire;     // 命令リタイア時に点滅 (LED2: T9)
    assign led[3] = cycles[24]; // 生存確認用 Heartbeat (LED3: T10)

endmodule

