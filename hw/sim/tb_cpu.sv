module tb_cpu;

    logic        clk;
    logic        rst_n;

    logic [31:0] pc;
    logic [31:0] inst;
    logic        mem_read;
    logic        mem_write;
    logic [31:0] mem_addr;
    logic [31:0] mem_wdata;
    logic [31:0] mem_rdata;

    cpu u_cpu (
        .clk       (clk),
        .rst_n     (rst_n),
        .pc        (pc),
        .inst      (inst),
        .mem_read  (mem_read),
        .mem_write (mem_write),
        .mem_addr  (mem_addr),
        .mem_wdata (mem_wdata),
        .mem_rdata (mem_rdata)
    );

    logic [31:0] memory [0:16383];

    assign inst = memory[pc[15:2]];
    assign mem_rdata = mem_read ? memory[mem_addr[15:2]] : 32'h0;

    string  hex_file;
    integer cycle_count = 0;
    bit     trace_en    = 0;

    always #5 clk = ~clk;

    initial begin
        $dumpfile("hw/sim/tb_cpu.vcd");
        $dumpvars(0, tb_cpu);

        // +trace 引数があるか
        if ($test$plusargs("trace")) trace_en = 1;

        // メモリのクリア
        for (int i = 0; i < 16384; i++) memory[i] = 32'h0;

        // Load test hex file
        if ($value$plusargs("hex=%s", hex_file)) $readmemh(hex_file, memory);
        else $readmemh("hw/sim/prog_basic.hex", memory);

        // Reset sequence
        clk   = 0;
        rst_n = 0;
        #25;
        rst_n = 1;
    end

    always_ff @(posedge clk) begin
        if (mem_write) begin
            if (mem_addr == 32'h1000_0000) begin
                // UART 出力
                $write("%c", mem_wdata[7:0]);
                $fflush();
            end else begin
                if (u_cpu.mem_wstrb[0]) memory[mem_addr[15:2]][7:0]   <= mem_wdata[7:0];
                if (u_cpu.mem_wstrb[1]) memory[mem_addr[15:2]][15:8]  <= mem_wdata[15:8];
                if (u_cpu.mem_wstrb[2]) memory[mem_addr[15:2]][23:16] <= mem_wdata[23:16];
                if (u_cpu.mem_wstrb[3]) memory[mem_addr[15:2]][31:24] <= mem_wdata[31:24];
            end
        end
    end

    always @(posedge clk) begin
        if (rst_n) begin
            cycle_count <= cycle_count + 1;

            if (trace_en) $display("Cycle %0d | PC: 0x%08h | Inst: 0x%08h", cycle_count, pc, inst);
            // if (trace_en) begin
            //     $display("C%0d | PC:%08h | Inst:%08h | src_a:%b | src_b:%b | wen:%b | wdata:%08h | rs1:%08h | rs2:%08h",
            //              cycle_count, pc, inst,
            //              u_cpu.alu_src_a,
            //              u_cpu.alu_src_b,
            //              u_cpu.u_controller.reg_write,
            //              u_cpu.u_datapath.result_data,
            //              u_cpu.u_datapath.rs1_data,
            //              u_cpu.u_datapath.rs2_data);
            // end

            // Self-loop detection: program termination
            if (inst == 32'h0000_006f) begin
                $display("\n--------------------------------------------------");
                $display("Program finished cleanly via self-loop.");
                $display("Total executed cycles: %0d", cycle_count);
                $display("--------------------------------------------------");
                #20;
                $finish;
            end

            // Timeout safety limit
            if (cycle_count > 50000000) begin
                $display("\n[TIMEOUT] Reached maximum cycle limit (%0d cycles).", cycle_count);
                $finish;
            end
        end
    end

endmodule

