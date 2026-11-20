module custom0 #(
    parameter bit QMUL_STALL    = 1'b1,
    parameter bit ENABLE_QMUL   = 1'b1,
    parameter bit ENABLE_QSQRT  = 1'b1,
    parameter bit ENABLE_QRSQRT = 1'b1,
    parameter bit ENABLE_QRCP   = 1'b1,
    parameter bit ENABLE_QRAND  = 1'b1
)(
    input  logic        clk,
    input  logic        rst_n,
    input  logic        valid,
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  logic [2:0]  funct3,
    output logic [31:0] result,
    output logic        stall
);

    // 1. qmul (funct3 = 3'b000): Q16.16 固定小数点乗算
    logic [31:0] qmul_res_out;
    logic        qmul_stall_out;

    generate
        if (ENABLE_QMUL) begin : gen_qmul
            logic signed [63:0] qmul_prod;
            assign qmul_prod = 64'(signed'(a)) * 64'(signed'(b));

            if (QMUL_STALL) begin : gen_qmul_stall
                logic        qmul_start;
                logic        qmul_done_q;
                logic [31:0] qmul_res_q;

                assign qmul_start = valid && (funct3 == 3'b000) && !qmul_done_q;

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

                assign qmul_res_out   = qmul_res_q;
                assign qmul_stall_out = !qmul_done_q;
            end else begin : gen_qmul_comb
                assign qmul_res_out   = qmul_prod[47:16];
                assign qmul_stall_out = 1'b0;
            end
        end else begin : gen_no_qmul
            assign qmul_res_out   = 32'd0;
            assign qmul_stall_out = 1'b0;
        end
    endgenerate

    // 2. qsqrt (funct3 = 3'b010): 開平演算器
    logic        sqrt_done;
    logic [31:0] sqrt_res;

    generate
        if (ENABLE_QSQRT) begin : gen_qsqrt
            logic sqrt_start, sqrt_busy;
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
        end else begin : gen_no_qsqrt
            assign sqrt_res  = 32'd0;
            assign sqrt_done = 1'b1;
        end
    endgenerate

    // 3. qrsqrt (funct3 = 3'b011): 逆平方根演算器
    logic        rsqrt_done;
    logic [31:0] rsqrt_res;

    generate
        if (ENABLE_QRSQRT) begin : gen_qrsqrt
            logic rsqrt_start, rsqrt_busy;
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
        end else begin : gen_no_qrsqrt
            assign rsqrt_res  = 32'd0;
            assign rsqrt_done = 1'b1;
        end
    endgenerate

    // 4. qrcp (funct3 = 3'b100): 逆数演算器
    logic        rcp_done;
    logic [31:0] rcp_res;

    generate
        if (ENABLE_QRCP) begin : gen_qrcp
            logic rcp_start, rcp_busy;
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
        end else begin : gen_no_qrcp
            assign rcp_res  = 32'd0;
            assign rcp_done = 1'b1;
        end
    endgenerate

    // 5. ハードウェア乱数生成器 (Xorshift32)
    // funct3 = 3'b101 (qseed) : rng_state <= a
    // funct3 = 3'b110 (qrand) : [0.0, 1.0) の q16 乱数を返しrng_state を更新
    // funct3 = 3'b111 (qrands): [-1.0, 1.0) の q16 乱数を返しrng_state を更新
    logic [31:0] rand_u_q16, rand_s_q16, qseed_res;

    generate
        if (ENABLE_QRAND) begin : gen_qrand
            logic [31:0] rng_state;
            logic [31:0] rng_x1, rng_x2, rng_next;

            assign rng_x1     = rng_state ^ (rng_state << 13);
            assign rng_x2     = rng_x1 ^ {17'd0, rng_x1[31:17]}; // (x >> 17) & 32767
            assign rng_next   = rng_x2 ^ (rng_x2 << 5);

            // ULP * ((raw.value >> 8) & 65535) と完全一致
            assign rand_u_q16 = {16'd0, rng_next[23:8]};
            // -1.0 + 2.0 * rand_u_q16 と完全一致
            assign rand_s_q16 = {{16{~rng_next[23]}}, rng_next[22:8], 1'b0};
            assign qseed_res  = a;

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    rng_state <= 32'd42;
                end else if (valid) begin
                    if (funct3 == 3'b101) begin
                        rng_state <= a;
                    end else if (funct3 == 3'b110 || funct3 == 3'b111) begin
                        rng_state <= rng_next;
                    end
                end
            end
        end else begin : gen_no_qrand
            assign rand_u_q16 = 32'd0;
            assign rand_s_q16 = 32'd0;
            assign qseed_res  = 32'd0;
        end
    endgenerate

    // 6. 出力選択 & ストール信号
    always_comb begin
        result = 32'd0;
        stall  = 1'b0;
        if (valid) begin
            case (funct3)
                3'b000: begin
                    result = qmul_res_out;
                    stall  = qmul_stall_out;
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
                3'b101: begin
                    result = qseed_res;
                    stall  = 1'b0;
                end
                3'b110: begin
                    result = rand_u_q16;
                    stall  = 1'b0;
                end
                3'b111: begin
                    result = rand_s_q16;
                    stall  = 1'b0;
                end
                default: begin
                    result = 32'd0;
                    stall  = 1'b0;
                end
            endcase
        end
    end

endmodule
