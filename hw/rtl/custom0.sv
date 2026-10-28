module custom0 (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        valid,
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  logic [2:0]  funct3,
    output logic [31:0] result,
    output logic        stall
);

    // 1. qmul (funct3 = 3'b000): Q16.16 固定小数点乗算 (DSPパイプライン化)
    // フォワーディングMUX -> DSP48E1 -> EX/MEMレジスタ の貫通パスを切るため、
    // 乗算結果を一旦レジスタ (qmul_res_q) にラッチして次のサイクルで完了させる。
    logic        qmul_start;
    logic        qmul_done_q;
    logic [31:0] qmul_res_q;
    logic signed [63:0] qmul_prod;

    assign qmul_start = valid && (funct3 == 3'b000) && !qmul_done_q;
    assign qmul_prod  = 64'(signed'(a)) * 64'(signed'(b));

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            qmul_done_q <= 1'b0;
            qmul_res_q  <= 32'd0;
        end else if (qmul_start) begin
            qmul_done_q <= 1'b1;
            qmul_res_q  <= qmul_prod[47:16];
        end else begin
            qmul_done_q <= 1'b0;
        end
    end

    // 2. qsqrt (funct3 = 3'b010): 開平演算器
    logic        sqrt_start, sqrt_busy, sqrt_done;
    logic [31:0] sqrt_res;

    assign sqrt_start = valid && (funct3 == 3'b010) && !sqrt_busy && !sqrt_done;

    qsqrt_unit u_qsqrt (
        .clk    (clk),
        .rst_n  (rst_n),
        .start  (sqrt_start),
        .a      (a),
        .result (sqrt_res),
        .busy   (sqrt_busy),
        .done   (sqrt_done)
    );

    // 3. qrsqrt (funct3 = 3'b011): 逆平方根演算器
    logic        rsqrt_start, rsqrt_busy, rsqrt_done;
    logic [31:0] rsqrt_res;

    assign rsqrt_start = valid && (funct3 == 3'b011) && !rsqrt_busy && !rsqrt_done;

    qrsqrt_unit u_qrsqrt (
        .clk    (clk),
        .rst_n  (rst_n),
        .start  (rsqrt_start),
        .a      (a),
        .result (rsqrt_res),
        .busy   (rsqrt_busy),
        .done   (rsqrt_done)
    );

    // 4. qrcp (funct3 = 3'b100): 逆数演算器
    logic        rcp_start, rcp_busy, rcp_done;
    logic [31:0] rcp_res;

    assign rcp_start = valid && (funct3 == 3'b100) && !rcp_busy && !rcp_done;

    qrcp_unit u_qrcp (
        .clk    (clk),
        .rst_n  (rst_n),
        .start  (rcp_start),
        .a      (a),
        .result (rcp_res),
        .busy   (rcp_busy),
        .done   (rcp_done)
    );

    // 5. 出力選択 & ストール信号 (すべて FF 出力から選択されるため高速)
    always_comb begin
        result = 32'd0;
        stall  = 1'b0;
        if (valid) begin
            case (funct3)
                3'b000: begin
                    result = qmul_res_q;
                    stall  = !qmul_done_q;
                end
                3'b010: begin
                    result = sqrt_res;
                    stall  = !sqrt_done;
                end
                3'b011: begin
                    result = rsqrt_res;
                    stall  = !rsqrt_done;
                end
                3'b100: begin
                    result = rcp_res;
                    stall  = !rcp_done;
                end
                default: begin
                    result = 32'd0;
                    stall  = 1'b0;
                end
            endcase
        end
    end

endmodule
