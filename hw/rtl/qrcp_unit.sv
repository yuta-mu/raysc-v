// qrcp_unit.sv
// [INT_MIN, INT_MAX] で飽和、x == 0 は 0x7FFFFFFF
module qrcp_unit (
    input  logic        clk,
    input  logic        rst_n,

    input  logic        start,
    input  logic [31:0] a,      // 入力値

    output logic [31:0] result,
    output logic        busy,   // 演算中
    output logic        done    // 演算完了
);

    `include "rcp_table.svh"

    typedef enum logic [2:0] {
        IDLE,   // 開始待ち
        S1,     // 初期値から誤差計算
        S2,     // ニュートン法1回目
        S3,     // 1回目から誤差計算
        S4,     // ニュートン法2回目
        S5,     // 補正用の余り計算
        S6,     // 補正量の決定
        RES     // 完了
    } state_t;

    state_t state;

    // 正規化
    logic        neg, zero, p2;
    logic [31:0] ax, ax_n, dn;
    logic [4:0]  s;
    logic [15:0] z0;

    assign neg  = a[31];
    assign zero = (a == 32'd0);
    assign ax   = neg ? (32'd0 - a) : a;                  // 絶対値
    assign p2   = ((ax & (ax - 32'd1)) == 32'd0);         // ax が 2 のべき乗
    assign ax_n = zero ? 32'd1 : ax;                      // 0 のときの clz を安全な値にする

    // 先頭の 0 の個数を求める
    always_comb begin
        s = 5'd31;
        for (int i = 0; i < 32; i++) begin
            if (ax_n[i]) s = 5'(31 - i);                  // 最後に代入されるのが最上位の 1 -> s = clz
        end
    end

    assign dn = ax_n << s;
    assign z0 = rcp_rom(dn[30:24]);

    // レジスタ
    logic [31:0] dn_q;  // 正規化済み入力
    logic [15:0] z0_q;  // 初期値
    logic [4:0]  s_q;   // 正規化したときのシフト量
    logic        neg_q, zero_q, p2_q;
    logic [32:0] e_q;   // ニュートン法に入れる値
    logic [32:0] z_q;   // 現在の近似値
    logic [63:0] rem_q; // 補正に使う余り
    logic [32:0] f_q;   // 補正後の商

    // 乗算器 (33bit x 33bit, 符号なし、状態ごとにオペランドを切り替える)
    logic [32:0] ma, mb;
    logic [65:0] prod;

    always_comb begin
        case (state)
            S1:      begin ma = {1'b0, dn_q};  mb = {17'd0, z0_q}; end
            S2:      begin ma = {17'd0, z0_q}; mb = e_q;           end
            S3:      begin ma = {1'b0, dn_q};  mb = z_q;           end
            S4:      begin ma = z_q;           mb = e_q;           end
            default: begin ma = {1'b0, dn_q};  mb = z_q;           end   // S5
        endcase
    end

    assign prod = ma * mb;

    // S1,S2で使う値（積）
    logic [65:0] t1, t3;
    assign t1 = (prod + 66'd8388607)  >> 23;              // (prod + 2^23 - 1) >> 23
    assign t3 = (prod + 66'd33554431) >> 25;              // (prod + 2^25 - 1) >> 25

    // 最終補正
    logic [63:0] dn64, dn64_x2, dn64_x3;
    logic [1:0]  k;
    logic [32:0] zf;

    assign dn64    = {32'd0, dn_q};
    assign dn64_x2 = {dn64[62:0], 1'b0};
    assign dn64_x3 = dn64 + dn64_x2;
    assign k       = (rem_q >= dn64) + (rem_q >= dn64_x2) + (rem_q >= dn64_x3);
    assign zf      = z_q + {31'd0, k};

    // 状態の繊維
    always_ff @(posedge clk or negedge rst_n) begin
        // 初期化
        if (!rst_n) begin
            state  <= IDLE;
            dn_q   <= '0;
            z0_q   <= '0;
            s_q    <= '0;
            neg_q  <= 1'b0;
            zero_q <= 1'b0;
            p2_q   <= 1'b0;
            e_q    <= '0;
            z_q    <= '0;
            rem_q  <= '0;
            f_q    <= '0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        dn_q   <= dn;
                        z0_q   <= z0;
                        s_q    <= s;
                        neg_q  <= neg;
                        zero_q <= zero;
                        p2_q   <= p2;
                        state  <= S1;
                    end
                end
                S1: begin
                    e_q   <= 33'h0_0200_0000 - t1[32:0];          // 2^25 - p1
                    state <= S2;
                end
                S2: begin
                    z_q   <= prod[47:15];                          // (Z0 * e) >> 15
                    state <= S3;
                end
                S3: begin
                    e_q   <= 33'h1_0000_0000 - t3[32:0];          // 2^32 - p2
                    state <= S4;
                end
                S4: begin
                    z_q   <= prod[56:24];                          // (Z1 * e) >> 24
                    state <= S5;
                end
                S5: begin
                    rem_q <= 64'h8000_0000_0000_0000 - prod[63:0]; // 2^63 - dn*Z2
                    state <= S6;
                end
                S6: begin
                    f_q   <= zf >> (~s_q);                         // >> (31 - s)
                    state <= RES;
                end
                RES: begin
                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end

    // 符号処理
    logic [33:0] c;

    always_comb begin
        c = {1'b0, f_q} + {33'd0, ~p2_q};                 // ceil(2^32 / ax) = f + (ax が 2 のべき乗でない)
        if (zero_q)
            result = 32'h7FFFFFFF;
        else if (!neg_q)
            result = (f_q > 33'h0_7FFF_FFFF) ? 32'h7FFFFFFF : f_q[31:0];
        else
            result = (c > 34'h0_8000_0000) ? 32'h80000000 : (32'd0 - c[31:0]);
    end

    assign busy = (state != IDLE);
    assign done = (state == RES);

endmodule