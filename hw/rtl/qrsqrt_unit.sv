// qrsqrt_unit.sv: 固定 9 サイクル
// rsqrt(x) = floor(2^24 / sqrt(x))
module qrsqrt_unit (
    input  logic        clk,
    input  logic        rst_n,

    input  logic        start,
    input  logic [31:0] a,

    output logic [31:0] result,
    output logic        busy,
    output logic        done
);

    `include "rsqrt_table.svh"

    typedef enum logic [3:0] {
        IDLE,
        IT1_S1, // y0 * y0
        IT1_S2, // w * y0^2
        IT1_S3, // y0 * (3 - w*y0^2)/2 -> y1
        IT2_S1, // y1 * y1
        IT2_S2, // w * y1^2
        IT2_S3, // y1 * (3 - w*y1^2)/2 -> y2, q_approx 確定
        CORR1,  // P1 = q * a (最大 40bit)
        CORR2,  // P2 = P1 * q = q^2 * a を 2^48 と比較して確定
        RES     // 出力完了
    } state_t;

    state_t state;

    // --- 1. 入力前処理 (IDLE 時にラッチ) ---
    logic        zero_in;
    logic [4:0]  clz_in, sh_in;
    logic [31:0] w_in;
    logic [15:0] y0_rom;
    logic [31:0] y0_in;

    assign zero_in = a[31] | (a == 32'd0);

    always_comb begin
        clz_in = 5'd31;
        for (int i = 0; i < 32; i++) begin
            if (a[i]) clz_in = 5'(31 - i);
        end
    end

    assign sh_in  = clz_in & 5'b11110;
    assign w_in   = a << sh_in;
    assign y0_rom = rsqrt_rom(w_in[31:24]);
    assign y0_in  = {y0_rom, 16'd0};

    // --- 2. 内部レジスタ ---
    logic [31:0] a_q, w_q;
    logic [4:0]  sh_q;
    logic        zero_q;
    logic [31:0] y_q, y_sq_q, diff_q;
    logic [31:0] q_approx;
    logic [39:0] qx_q;     // P1 = q * a (最大 40bit)
    logic [31:0] q_final;

    // --- 3. 共有乗算器 (40bit x 32bit -> 72bit) ---
    logic [39:0] ma;
    logic [31:0] mb;
    logic [71:0] prod;

    always_comb begin
        case (state)
            IT1_S1, IT2_S1: begin ma = {8'd0, y_q};      mb = y_q;      end
            IT1_S2, IT2_S2: begin ma = {8'd0, w_q};      mb = y_sq_q;   end
            IT1_S3, IT2_S3: begin ma = {8'd0, y_q};      mb = diff_q;   end
            CORR1:          begin ma = {8'd0, q_approx}; mb = a_q;      end // P1 = q * a
            CORR2:          begin ma = qx_q;             mb = q_approx; end // P2 = P1 * q = q^2 * a
            default:        begin ma = '0;               mb = '0;       end
        endcase
    end

    assign prod = {32'd0, ma} * {40'd0, mb};

    // --- 4. スケーリング復帰シフト量 ---
    logic [4:0] shift_amt;
    assign shift_amt = 5'd22 - (sh_q >> 1);

    // --- 5. CORR2 での境界比較ロジック ---
    // P2 = q^2 * a
    // next_P2 = (q + 1)^2 * a = P2 + 2*P1 + a
    logic [63:0] p2_val;
    logic [63:0] next_p2_val;
    assign p2_val      = prod[63:0];
    assign next_p2_val = prod[63:0] + {23'd0, qx_q, 1'b0} + {32'd0, a_q};

    // --- 6. 状態遷移 ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= IDLE;
            a_q      <= '0;
            w_q      <= '0;
            sh_q     <= '0;
            zero_q   <= 1'b0;
            y_q      <= '0;
            y_sq_q   <= '0;
            diff_q   <= '0;
            q_approx <= '0;
            qx_q     <= '0;
            q_final  <= '0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        a_q    <= a;
                        w_q    <= w_in;
                        sh_q   <= sh_in;
                        zero_q <= zero_in;
                        y_q    <= y0_in;
                        state  <= IT1_S1;
                    end
                end

                // === 反復 1 ===
                IT1_S1: begin
                    y_sq_q <= prod[63:32];
                    state  <= IT1_S2;
                end
                IT1_S2: begin
                    diff_q <= (32'hC000_0000 - prod[61:30]) >> 1;
                    state  <= IT1_S3;
                end
                IT1_S3: begin
                    y_q    <= prod[61:30];
                    state  <= IT2_S1;
                end

                // === 反復 2 ===
                IT2_S1: begin
                    y_sq_q <= prod[63:32];
                    state  <= IT2_S2;
                end
                IT2_S2: begin
                    diff_q <= (32'hC000_0000 - prod[61:30]) >> 1;
                    state  <= IT2_S3;
                end
                IT2_S3: begin
                    y_q      <= prod[61:30];
                    q_approx <= prod[61:30] >> shift_amt;
                    state    <= CORR1;
                end

                // === 補正 1: P1 = q * a (40bit) ===
                CORR1: begin
                    qx_q  <= prod[39:0];
                    state <= CORR2;
                end

                // === 補正 2: q^2 * a <= 2^48 < (q+1)^2 * a の厳密判定 ===
                CORR2: begin
                    if (p2_val > 64'h0001_0000_0000_0000) begin
                        q_final <= q_approx - 32'd1;
                    end else if (next_p2_val <= 64'h0001_0000_0000_0000) begin
                        q_final <= q_approx + 32'd1;
                    end else begin
                        q_final <= q_approx;
                    end
                    state <= RES;
                end

                RES: begin
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    assign result = zero_q ? 32'd0 : q_final;
    assign busy   = (state != IDLE);
    assign done   = (state == RES);

endmodule
