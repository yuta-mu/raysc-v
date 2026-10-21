// tb_custom0.sv : custom0 テストベンチ
//   iverilog -g2012 -I../rtl -o sim_c0 ../rtl/qsqrt_unit.sv ../rtl/qrcp_unit.sv \
//            ../rtl/qrsqrt_unit.sv ../rtl/custom0.sv tb_custom0.sv
//   vvp sim_c0 +SQRT=vec.hex +RCP=vec_rcp.hex +RSQRT=vec_rsqrt.hex
`timescale 1ns/1ps

module tb_custom0;

    localparam int MAXV = 1 << 20;

    logic clk   = 1'b0;
    logic rst_n = 1'b0;
    always #5 clk = ~clk;

    logic        valid  = 1'b0;
    logic [31:0] a      = 32'd0;
    logic [31:0] b      = 32'd0;
    logic [2:0]  funct3 = 3'd0;
    logic [31:0] result;
    logic        stall;

    custom0 dut (
        .clk(clk), .rst_n(rst_n), .valid(valid), .a(a), .b(b), .funct3(funct3),
        .result(result), .stall(stall)
    );

    // ---------------- ベクタ ----------------
    logic [31:0] mem_sqrt  [0:2*MAXV-1];
    logic [31:0] mem_rcp   [0:2*MAXV-1];
    logic [31:0] mem_rsqrt [0:2*MAXV-1];
    int          n_sqrt, n_rcp, n_rsqrt;

    logic [8*256-1:0] f_sqrt, f_rcp, f_rsqrt;
    int               errors, ops, max_cyc;

    // qmul の期待値 (仕様: floor(a*b / 2^16) の下位 32bit)
    function automatic logic [31:0] qmul_ref(input logic [31:0] x, input logic [31:0] y);
        longint p;
        begin
            p = longint'($signed(x)) * longint'($signed(y));
            return p[47:16];
        end
    endfunction

    // 1 命令を実行して検査する
    task automatic do_op(input logic [2:0] f3, input logic [31:0] x, input logic [31:0] y,
                         input logic [31:0] expv, input string name);
        int cyc;
        logic multi;
        begin
            multi  = (f3 == 3'd2) || (f3 == 3'd3) || (f3 == 3'd4);
            funct3 = f3;
            a      = x;
            b      = y;
            valid  = 1'b1;
            cyc    = 0;
            #1;
            if (multi && stall !== 1'b1) begin
                errors++;
                if (errors <= 20) $display("PROTOCOL (%s): stall should be 1 in the first cycle, x=%08h", name, x);
            end
            while (stall !== 1'b0) begin
                @(posedge clk);
                #1;
                cyc++;
                if (cyc == 1 && multi) begin a = 32'hDEADBEEF; b = 32'hCAFEF00D; end  // 取り込み後に変えても影響しない
                if (cyc > 80) begin
                    $display("FAIL: timeout (%s) x=%08h", name, x);
                    errors++;
                    $finish;
                end
            end
            if (cyc > max_cyc) max_cyc = cyc;
            if (result !== expv) begin
                errors++;
                if (errors <= 20)
                    $display("MISMATCH (%s): x=%08h y=%08h expected=%08h got=%08h", name, x, y, expv, result);
            end
            ops++;
            @(posedge clk);          // CPU が次の命令へ進む
            #1;
        end
    endtask

    int i, k, sel;
    logic [31:0] ra, rb;

    initial begin
        if (!$value$plusargs("SQRT=%s",  f_sqrt))  f_sqrt  = "vec.hex";
        if (!$value$plusargs("RCP=%s",   f_rcp))   f_rcp   = "vec_rcp.hex";
        if (!$value$plusargs("RSQRT=%s", f_rsqrt)) f_rsqrt = "vec_rsqrt.hex";

        for (i = 0; i < 2*MAXV; i++) begin
            mem_sqrt[i] = 32'hxxxxxxxx; mem_rcp[i] = 32'hxxxxxxxx; mem_rsqrt[i] = 32'hxxxxxxxx;
        end
        $readmemh(f_sqrt,  mem_sqrt);
        $readmemh(f_rcp,   mem_rcp);
        $readmemh(f_rsqrt, mem_rsqrt);
        n_sqrt = 0;  while (n_sqrt  < MAXV && (^mem_sqrt[2*n_sqrt]   !== 1'bx)) n_sqrt++;
        n_rcp = 0;   while (n_rcp   < MAXV && (^mem_rcp[2*n_rcp]     !== 1'bx)) n_rcp++;
        n_rsqrt = 0; while (n_rsqrt < MAXV && (^mem_rsqrt[2*n_rsqrt] !== 1'bx)) n_rsqrt++;
        if (n_sqrt == 0 || n_rcp == 0 || n_rsqrt == 0) begin
            $display("FAIL: vector files not read (sqrt=%0d rcp=%0d rsqrt=%0d)", n_sqrt, n_rcp, n_rsqrt);
            $finish;
        end

        errors = 0; ops = 0; max_cyc = 0;

        repeat (3) @(posedge clk);
        #1 rst_n = 1'b1;
        @(posedge clk);
        #1;

        // ---- フェーズ A ----
        for (i = 0; i < n_sqrt;  i++) do_op(3'd2, mem_sqrt[2*i],  32'd0, mem_sqrt[2*i+1],  "qsqrt");
        $display("  A: qsqrt  %0d ops done", n_sqrt);
        for (i = 0; i < n_rcp;   i++) do_op(3'd4, mem_rcp[2*i],   32'd0, mem_rcp[2*i+1],   "qrcp");
        $display("  A: qrcp   %0d ops done", n_rcp);
        for (i = 0; i < n_rsqrt; i++) do_op(3'd3, mem_rsqrt[2*i], 32'd0, mem_rsqrt[2*i+1], "qrsqrt");
        $display("  A: qrsqrt %0d ops done", n_rsqrt);

        // ---- フェーズ B: ランダムな順序で混ぜる ----
        for (i = 0; i < 200000; i++) begin
            sel = $urandom_range(0, 4);
            case (sel)
                0: begin  // qmul (ランダムなオペランド、桁数をばらつかせる)
                    ra = $urandom >> $urandom_range(0, 31);
                    rb = $urandom >> $urandom_range(0, 31);
                    if ($urandom_range(0, 1)) ra = 32'd0 - ra;
                    if ($urandom_range(0, 1)) rb = 32'd0 - rb;
                    do_op(3'd0, ra, rb, qmul_ref(ra, rb), "qmul");
                end
                1: begin k = $urandom_range(0, n_sqrt  - 1); do_op(3'd2, mem_sqrt[2*k],  32'd0, mem_sqrt[2*k+1],  "qsqrt");  end
                2: begin k = $urandom_range(0, n_rsqrt - 1); do_op(3'd3, mem_rsqrt[2*k], 32'd0, mem_rsqrt[2*k+1], "qrsqrt"); end
                3: begin k = $urandom_range(0, n_rcp   - 1); do_op(3'd4, mem_rcp[2*k],   32'd0, mem_rcp[2*k+1],   "qrcp");   end
                default: begin  // 未定義の funct3 は 0 を返し、stall しない
                    ra = $urandom;
                    do_op(($urandom_range(0, 1) ? 3'd1 : 3'd5), ra, $urandom, 32'd0, "undef");
                end
            endcase
        end
        $display("  B: random mix done");

        valid = 1'b0;
        @(posedge clk);
        #1;
        if (stall !== 1'b0) begin
            errors++;
            $display("PROTOCOL: stall should be 0 when valid = 0");
        end

        if (errors == 0) $display("PASS: %0d ops (max stall %0d cycles)", ops, max_cyc);
        else             $display("FAIL: %0d errors in %0d ops", errors, ops);
        $finish;
    end

endmodule