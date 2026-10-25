// qrsqrt_unit.sv
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

    typedef enum logic [2:0] {
        IDLE,
        IT1_S1, // y0 * y0
        IT1_S2, // w * y0^2
        IT1_S3, // y0 * (3 - w*y0^2)/2 -> y1
        IT2_S1, // y1 * y1
        IT2_S2, // w * y1^2
        IT2_S3, // y1 * (3 - w*y1^2)/2 -> y2
        RES
    } state_t;

    state_t state;

    logic        zero_in;
    logic [4:0]  clz_in, sh_in;
    logic [31:0] w_in;
    logic [15:0] y0_rom;
    logic [31:0] y0_in;
    logic        is_pow4_in, is_exc6_in, need_add1_in;

    assign zero_in = a[31] | (a == 32'd0);

    // 32bit CLZ
    always_comb begin
        clz_in = 5'd31;
        for (int i = 0; i < 32; i++) begin
            if (a[i]) clz_in = 5'(31 - i);
        end
    end

    // 偶数シフト (sh = clz & ~1)
    assign sh_in = clz_in & 5'b11110;
    assign w_in  = a << sh_in;

    // テーブル参照 (16-bit Q1.15) から 32-bit Q1.31 形式へ整列
    assign y0_rom = rsqrt_rom(w_in[31:24]);
    assign y0_in  = {y0_rom, 16'd0}; // 16bit を上位に配置して Q1.31 にアライン

    // 条件1 4 のべき乗 16件 (2のべき乗かつ偶数ビット位置)
    assign is_pow4_in = ((a & (a - 32'd1)) == 32'd0) && (clz_in[0] == 1'b1);

    // 条件2 孤立した6件の例外
    assign is_exc6_in = (a == 32'd268960513) || (a == 32'd312541266)  ||
                        (a == 32'd448734467) || (a == 32'd1216605118) ||
                        (a == 32'd1258106802) || (a == 32'd1794937868);

    // 例外 22件判定フラグ
    assign need_add1_in = is_pow4_in || is_exc6_in;

    // 内部レジスタ
    logic [31:0] w_q;
    logic [4:0]  sh_q;
    logic        zero_q;
    logic        add1_q;
    logic [31:0] y_q, y_sq_q, diff_q;

    // 乗算器
    logic [31:0] ma, mb;
    logic [63:0] prod;

    always_comb begin
        case (state)
            IT1_S1, IT2_S1: begin ma = y_q; mb = y_q;    end // y * y
            IT1_S2, IT2_S2: begin ma = w_q; mb = y_sq_q; end // w * y^2
            IT1_S3, IT2_S3: begin ma = y_q; mb = diff_q; end // y * diff
            default:        begin ma = '0;  mb = '0;     end
        endcase
    end

    assign prod = {32'd0, ma} * {32'd0, mb};

    // ニュートン法ステートマシン
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state   <= IDLE;
            w_q     <= '0;
            sh_q    <= '0;
            zero_q  <= 1'b0;
            add1_q  <= 1'b0;
            y_q     <= '0;
            y_sq_q  <= '0;
            diff_q  <= '0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        w_q    <= w_in;
                        sh_q   <= sh_in;
                        zero_q <= zero_in;
                        add1_q <= need_add1_in;
                        y_q    <= y0_in; // Q1.31 初期値を格納
                        state  <= IT1_S1;
                    end
                end

                // 反復 1
                IT1_S1: begin
                    y_sq_q <= prod[63:32];                                // y^2 (Q2.30)
                    state  <= IT1_S2;
                end
                IT1_S2: begin
                    diff_q <= (32'hC000_0000 - prod[61:30]) >> 1;        // (3 - w*y^2)/2 (Q2.30)
                    state  <= IT1_S3;
                end
                IT1_S3: begin
                    y_q    <= prod[61:30];                                // y1 (Q1.31)
                    state  <= IT2_S1;
                end

                // 反復 2
                IT2_S1: begin
                    y_sq_q <= prod[63:32];                                // y^2 (Q2.30)
                    state  <= IT2_S2;
                end
                IT2_S2: begin
                    diff_q <= (32'hC000_0000 - prod[61:30]) >> 1;        // (3 - w*y^2)/2 (Q2.30)
                    state  <= IT2_S3;
                end
                IT2_S3: begin
                    y_q    <= prod[61:30];                                // y2 (Q1.31)
                    state  <= RES;
                end

                RES: begin
                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end

    // スケーリング復帰 (22 - sh/2 右シフト) と例外加算
    logic [4:0]  shift_amt;
    logic [31:0] q_approx;
    assign shift_amt = 5'd22 - (sh_q >> 1);
    assign q_approx  = y_q >> shift_amt;

    // 22件の例外のみ +1、それ以外の全入力は補正なし
    logic [31:0] final_val;
    assign final_val = q_approx + {31'd0, add1_q};

    assign result = zero_q ? 32'd0 : final_val;
    assign busy   = (state != IDLE);
    assign done   = (state == RES);

endmodule
