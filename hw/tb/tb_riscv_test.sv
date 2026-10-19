`timescale 1ns / 1ps

module tb_riscv_test;
    logic clk;
    logic rst_n;

    // クロック生成 (50MHz)
    initial clk = 0;
    always #10 clk = ~clk;

    // CPU ポート接続用信号
    logic [31:0] pc;
    logic [31:0] inst;
    logic        mem_read;
    logic        mem_write;
    logic [31:0] mem_addr;
    logic [31:0] mem_wdata;
    logic [3:0]  mem_wstrb;
    logic [31:0] mem_rdata;

    // H-1: 停止およびカウンタ信号
    logic        halted;
    logic [63:0] cycles;
    logic [63:0] instret;
    logic        retire;

    logic        uart_stall;
    assign       uart_stall = 1'b0;

    cpu u_cpu (
    .*
    );

bram #(
    .MEM_WORDS(65536)
  ) u_bram (
    .clk     (clk),
    // Port A: 命令フェッチ
    .a_addr  (pc),
    .a_rdata (inst),
    // Port B: データ読み書き
    .b_en    (mem_read || mem_write),
    .b_we    (mem_write),
    .b_wstrb (mem_wstrb),
    .b_addr  (mem_addr),
    .b_wdata (mem_wdata),
    .b_rdata (mem_rdata)
  );

    reg [1023:0] hex_file;
    initial begin
    rst_n = 0;
    for (int i = 0; i < 65536; i++) u_bram.mem[i] = 32'h0;
    if ($value$plusargs("HEX=%s", hex_file)) begin
            $readmemh(hex_file, u_bram.mem);
        end else begin
            $display("[ERROR] No +HEX argument provided!");
            $finish;
        end
    #20;
    rst_n = 1;
    end

  // ebreak 停止（halted）による合否判定
    wire [31:0] gp = u_cpu.u_datapath.u_regfile.rf[3];
    wire [31:0] a0 = u_cpu.u_datapath.u_regfile.rf[10];

    always @(posedge clk) begin
        if (rst_n && halted) begin
            #1; // 信号確定待ち
            if (gp == 32'd1) begin
                $display("RESULT: PASS (cycles=%0d, instret=%0d)", cycles, instret);
            end else begin
                // riscv_test.h で FAIL 時に (testnum << 1) | 1 をセットしているため、右シフトで復元
                $display("RESULT: FAIL (Failed at sub-test %0d, gp=%0d, a0=%0d)", gp >> 1, gp, a0);
          end
          $finish;
        end
    end

    // タイムアウト設定
    initial begin
        #1000000;
        $display("RESULT: TIMEOUT (pc=0x%08h, inst=0x%08h)", pc, inst);
        $finish;
    end

endmodule

