// qsqrt_unit.sv
// qsqrt (Q16.16 平方根)
module qsqrt_unit #(
    parameter int STEPS = 4
) (
    input  logic        clk,
    input  logic        rst_n,

    input  logic        start,   // 計算開始
    input  logic [31:0] a,       // 入力値

    output logic [31:0] result,  // 出力値
    output logic        busy,    // 計算処理中
    output logic        done     // 計算完了
);

    localparam int ITER = 24 / STEPS;

    typedef enum logic [1:0] {
        IDLE,  // 待機中
        RUN,   // 計算中（ITER回終了でFINISH）
        FINISH // 完了
    } state_t;

    state_t state, next_state;

    logic [4:0]  count;    // RUN中の計算回数
    logic [47:0] n;        // これから取り込む入力ビット
    logic [27:0] rem;      // 部分剰余（これまでのあまり）
    logic [23:0] root;     // 部分平方根（決定済みの平方根）
    logic        is_zero;  // x <= 0

    logic [47:0] n_nxt;
    logic [27:0] rem_nxt;
    logic [23:0] root_nxt;
    logic [27:0] rem_t, trial;

    always_comb begin
        // 初期化
        n_nxt    = n;
        rem_nxt  = rem;
        root_nxt = root;
        rem_t    = '0;
        trial    = '0;
        for (int k = 0; k < STEPS; k++) begin
            // 1. 2ビット取り込み
            rem_t = {rem_nxt[25:0], n_nxt[47:46]};
            // 2. 比較して次のビットを決定
            trial = {2'b00, root_nxt, 2'b01};
            if (rem_t >= trial) begin // 引ける
                rem_nxt  = rem_t - trial;
                root_nxt = {root_nxt[22:0], 1'b1};
            end else begin            // 引けない
                rem_nxt  = rem_t;
                root_nxt = {root_nxt[22:0], 1'b0};
            end
            // 3. 処理済みの2ビットをシフト
            n_nxt = {n_nxt[45:0], 2'b00};
        end
    end

    // 状態をnext_stateからstateに遷移
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else        state <= next_state;
    end

    // 次の状態を計算
    always_comb begin
        case (state)
            IDLE:    next_state = state_t'(start ? RUN : IDLE);
            RUN:     next_state = state_t'((count == 5'(ITER - 1)) ? FINISH : RUN);
            FINISH:  next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // 計算結果の保存
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count   <= '0;
            n       <= '0;
            rem     <= '0;
            root    <= '0;
            is_zero <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        count   <= '0;
                        n       <= {1'b0, a[30:0], 16'd0};
                        rem     <= '0;
                        root    <= '0;
                        is_zero <= a[31] | (a == 32'd0);
                    end
                end

                RUN: begin
                    count <= count + 5'd1;
                    n     <= n_nxt;
                    rem   <= rem_nxt;
                    root  <= root_nxt;
                end

                default: begin
                end
            endcase
        end
    end

    assign result = is_zero ? 32'd0 : {8'd0, root};
    assign busy   = (state == RUN) || (state == FINISH);
    assign done   = (state == FINISH);

endmodule