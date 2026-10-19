module top (
    input  logic       CLK100MHZ, // Arty A7 100MHz 水晶発振器 (Pin E3)
    input  logic       ck_rst,    // RESET (Pin C2, Actuve-Low)
    output logic       uart_tx,   // FTDI USB-UART TX ピン (Pin D10)
    output logic [3:0] led        // ステータス確認用 LED (Pin H5, J5, T9, T10)
);

    logic clk_toggle = 1'b0;
    always_ff @(posedge CLK100MHZ) begin
        clk_toggle <= ~clk_toggle;
    end

    logic clk;
    // 分周したクロックを FPGA のクロック専用配線網に乗せる
    BUFG u_bufg (
        .I(clk_toggle),
        .O(clk)
    );


    logic rst_sync_0, rst_n;
    always_ff @(posedge clk or negedge ck_rst) begin
        if (!ck_rst) begin
            rst_sync_0 <= 1'b0;
            rst_n      <= 1'b0;
        end else begin
            rst_sync_0 <= 1'b1;
            rst_n      <= rst_sync_0;
        end
    end

    localparam logic [31:0] MEM_BYTES  = 32'h0004_0000; // 256 KB
    localparam logic [31:0] UART_ADDR  = 32'h1000_0000;
    localparam logic [31:0] CYCLE_ADDR = 32'h2000_0000;

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
    logic [31:0] cycle_rdata_d;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_addr_d    <= '0;
            mem_read_d    <= 1'b0;
            cycle_rdata_d <= '0;
        end else begin
            mem_addr_d    <= mem_addr;
            mem_read_d    <= mem_read;
            cycle_rdata_d <= cycles[31:0];
        end
    end

    assign mem_rdata = !mem_read_d                ? 32'h0 :
                       (mem_addr_d < MEM_BYTES)   ? bram_rdata :
                       (mem_addr_d == CYCLE_ADDR) ? cycle_rdata_d : 32'h0;

    assign led[0] = halted;     // ebreak 等で正常停止したら点灯 (LED0: H5)
    assign led[1] = uart_stall; // FIFO が満杯になったら点灯 (LED1: J5)
    assign led[2] = retire;     // 命令リタイア時に点滅 (LED2: T9)
    assign led[3] = cycles[24]; // 生存確認用 (LED3: T10)

endmodule
