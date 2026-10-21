// qrsqrt_unit
// qrsqrt (= rcp(sqrt(x)))
module qrsqrt_unit #(
    parameter int STEPS = 4
) (
    input  logic        clk,
    input  logic        rst_n,

    input  logic        start,
    input  logic [31:0] a,

    output logic [31:0] result,
    output logic        busy,
    output logic        done
);

    typedef enum logic [1:0] {
        IDLE,
        SQRT,
        WAIT
    } state_t;

    state_t state;

    logic        zero_q;
    logic        sqrt_start, sqrt_done;
    logic [31:0] sqrt_result;
    logic        rcp_start, rcp_done;
    logic [31:0] rcp_result;

    assign sqrt_start = (state == IDLE) && start;
    assign rcp_start  = (state == SQRT) && sqrt_done;

    qsqrt_unit #(.STEPS(STEPS)) u_sqrt (
        .clk    (clk),
        .rst_n  (rst_n),
        .start  (sqrt_start),
        .a      (a),
        .result (sqrt_result),
        .busy   (),
        .done   (sqrt_done)
    );

    qrcp_unit u_rcp (
        .clk    (clk),
        .rst_n  (rst_n),
        .start  (rcp_start),
        .a      (sqrt_result),
        .result (rcp_result),
        .busy   (),
        .done   (rcp_done)
    );

    // 状態管理
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state  <= IDLE;
            zero_q <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        zero_q <= a[31] | (a == 32'd0);
                        state  <= SQRT;
                    end
                end
                SQRT: begin
                    if (sqrt_done) state <= WAIT;
                end
                WAIT: begin
                    if (rcp_done) state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end

    assign result = zero_q ? 32'd0 : rcp_result;
    assign busy   = (state != IDLE);
    assign done   = (state == WAIT) && rcp_done;

endmodule