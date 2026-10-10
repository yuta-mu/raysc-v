// =============================================================================
// tb_cpu.sv  --  自作コア用テストベンチ (make run / make check から呼ばれる)
//
// plusargs
//   +hex=FILE           必須。プログラム (readmemh 形式)
//   +uart=FILE          UART 出力を「1 バイト = 2 桁 16 進 1 行」で FILE に書く
//                       (省略時は stdout に %c で出す。バイナリ(0x00)を正しく扱うため check では必ず指定)
//   +maxcycles=N        打ち切りサイクル数 (既定 50000000)。超えると [TIMEOUT] を表示して終了
//   +retire_trace=FILE  retire トレース (pc inst) を FILE に書く (省略時は書かない)
//   +vcd=FILE           波形を FILE に書く (省略時は書かない。遅くなるので既定オフ)
//   +trace              毎サイクルの PC / 命令を stdout に表示
//
// 終了条件 (どれも最終行に [HALT] ... を表示する)
//   ebreak (0x00100073)       RayQ の正常終了 (仕様 §8)
//   自己ループ (0x0000006f)   従来の riscv-tests / 手書きアセンブリ用
//
// メモリマップ (仕様 §1): 0x0000_0000-0x0003_FFFF = 256 KB, 0x1000_0000 = UART, 0x2000_0000 = cycles
// =============================================================================
module tb_cpu;

    localparam int          MEM_WORDS = 65536;                 // 256 KB
    localparam logic [31:0] MEM_BYTES = 32'h0004_0000;
    localparam logic [31:0] UART_ADDR = 32'h1000_0000;
    localparam logic [31:0] CYCLE_ADDR = 32'h2000_0000;
    localparam logic [31:0] EBREAK    = 32'h0010_0073;
    localparam logic [31:0] SELF_LOOP = 32'h0000_006f;

    logic        clk;
    logic        rst_n;

    logic [31:0] pc;
    logic [31:0] inst;
    logic        mem_read;
    logic        mem_write;
    logic [31:0] mem_addr;
    logic [31:0] mem_wdata;
    logic [31:0] mem_rdata;
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
        .mem_rdata (mem_rdata),
        .retire    (retire)
    );

    logic [31:0] memory [0:MEM_WORDS-1];

    assign inst = memory[pc[17:2]];

    // 読み出し: メモリ / cycles(下位32bit。更新前の値) / それ以外は 0
    assign mem_rdata = !mem_read                ? 32'h0 :
                       (mem_addr < MEM_BYTES)   ? memory[mem_addr[17:2]] :
                       (mem_addr == CYCLE_ADDR) ? cycle_count[31:0] : 32'h0;

    string           hex_file, uart_file, trace_file, vcd_file;
    longint unsigned cycle_count = 0;      // リセット解除後の経過サイクル
    longint unsigned instret     = 0;      // retire した命令数 (ebreak は数えない)
    longint unsigned max_cycles  = 50000000;
    integer          uart_fd     = 0;
    integer          trace_fd    = 0;
    bit              trace_en    = 0;

    always #5 clk = ~clk;

    initial begin
        clk   = 0;
        rst_n = 0;

        if ($test$plusargs("trace")) trace_en = 1;
        if ($value$plusargs("maxcycles=%d", max_cycles)) ;
        if ($value$plusargs("vcd=%s", vcd_file)) begin
            $dumpfile(vcd_file);
            $dumpvars(0, tb_cpu);
        end
        if ($value$plusargs("uart=%s", uart_file))        uart_fd  = $fopen(uart_file, "w");
        if ($value$plusargs("retire_trace=%s", trace_file)) trace_fd = $fopen(trace_file, "w");

        for (int i = 0; i < MEM_WORDS; i++) memory[i] = 32'h0;
        if ($value$plusargs("hex=%s", hex_file)) $readmemh(hex_file, memory);
        else $fatal(1, "+hex=FILE is required");

        #25;
        rst_n = 1;
    end

    // ストア: UART / メモリ。未割り当てアドレスへのストアは警告して捨てる(別アドレスへの折り返しを防ぐ)
    always @(posedge clk) begin
        if (mem_write) begin
            if (mem_addr == UART_ADDR) begin
                if (uart_fd != 0) $fdisplay(uart_fd, "%02x", mem_wdata[7:0]);
                else begin
                    $write("%c", mem_wdata[7:0]);
                    $fflush();
                end
            end else if (mem_addr < MEM_BYTES) begin
                if (u_cpu.mem_wstrb[0]) memory[mem_addr[17:2]][7:0]   <= mem_wdata[7:0];
                if (u_cpu.mem_wstrb[1]) memory[mem_addr[17:2]][15:8]  <= mem_wdata[15:8];
                if (u_cpu.mem_wstrb[2]) memory[mem_addr[17:2]][23:16] <= mem_wdata[23:16];
                if (u_cpu.mem_wstrb[3]) memory[mem_addr[17:2]][31:24] <= mem_wdata[31:24];
            end else begin
                $display("[WARN] store to unmapped address 0x%08h (pc=0x%08h)", mem_addr, pc);
            end
        end
    end

    task automatic finish_sim(input string kind);
        // 最終 cycles は ebreak をコミットしたサイクルまで数える (仕様 §8: 最終 cycles = t_h + 1)
        $display("[HALT] kind=%s pc=0x%08h cycles=%0d instret=%0d", kind, pc, cycle_count + 1, instret);
        if (uart_fd  != 0) $fclose(uart_fd);
        if (trace_fd != 0) $fclose(trace_fd);
        $finish;
    endtask

    always @(posedge clk) begin
        if (rst_n) begin
            if (trace_en) $display("Cycle %0d | PC: 0x%08h | Inst: 0x%08h", cycle_count, pc, inst);

            if (retire && trace_fd != 0) $fwrite(trace_fd, "%08x %08x\n", pc, inst);
            if (retire && inst != EBREAK) instret <= instret + 1;
            cycle_count <= cycle_count + 1;

            // 単一サイクルコアでは、命令を取り込んだサイクルで ebreak が実行される。
            // (パイプライン化したら、retire 段の pc / 命令で判定するよう置き換える)
            if (inst == EBREAK)    finish_sim("ebreak");
            if (inst == SELF_LOOP) finish_sim("self-loop");

            if (cycle_count > max_cycles) begin
                $display("[TIMEOUT] Reached maximum cycle limit (%0d cycles).", cycle_count);
                $finish;
            end
        end
    end

endmodule

