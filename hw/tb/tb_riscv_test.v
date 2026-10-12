`timescale 1ns / 1ps

module tb_riscv_test;
  logic clk;
  logic rst_n;

  // クロック生成 (50MHz)
  initial clk = 0;
  always #10 clk = ~clk;

  // メモリ配列 (256KB: 64K ワード)
  logic [31:0] mem [0:65535];

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

  cpu u_cpu (
    .clk       (clk),
    .rst_n     (rst_n),
    .pc        (pc),
    .inst      (inst),
    .mem_read  (mem_read),
    .mem_write (mem_write),
    .mem_addr  (mem_addr),
    .mem_wdata (mem_wdata),
    .mem_wstrb (mem_wstrb),
    .mem_rdata (mem_rdata),
    .halted    (halted),
    .cycles    (cycles),
    .instret   (instret),
    .retire    (retire)
  );

  // 1. 命令フェッチ (ワードアドレス: pc[17:2])
  assign inst = mem[pc[17:2]];

  // 2. データ読み出し (ワードアドレス: mem_addr[17:2])
  assign mem_rdata = mem[mem_addr[17:2]];

  // 3. データ書き込み (mem_wstrb に応じたバイト単位の反映)
  wire [15:0] word_idx = mem_addr[17:2];
  always @(posedge clk) begin
    if (mem_write) begin
      if (mem_wstrb[0]) mem[word_idx][7:0]   <= mem_wdata[7:0];
      if (mem_wstrb[1]) mem[word_idx][15:8]  <= mem_wdata[15:8];
      if (mem_wstrb[2]) mem[word_idx][23:16] <= mem_wdata[23:16];
      if (mem_wstrb[3]) mem[word_idx][31:24] <= mem_wdata[31:24];
    end
  end

  // 4. Hex ファイルのロード
  reg [1023:0] hex_file;
  initial begin
    rst_n = 0;
    if ($value$plusargs("HEX=%s", hex_file)) begin
      $readmemh(hex_file, mem);
    end else begin
      $display("[ERROR] No +HEX argument provided!");
      $finish;
    end
    #20;
    rst_n = 1;
  end

  // 5. ebreak 停止（halted）による合否判定
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
    #200000;
    $display("RESULT: TIMEOUT");
    $finish;
  end

endmodule

