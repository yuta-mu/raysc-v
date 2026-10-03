`include "rv32i_types.svh"

module divider (
    input  logic        clk,
    input  logic        rst_n,

    input  logic        start,
    input  logic [2:0]  funct3,
    input  logic [31:0] a,
    input  logic [31:0] b,

    output logic [31:0] result,
    output logic        busy,
    output logic        done
);

    typedef enum logic [1:0] {
        IDLE,
        DIVIDE,
        FINISH
    } state_t;

    state_t state, next_state;

    logic [4:0]  count;
    logic [31:0] divisor;
    logic [63:0] rem_quot; // [63:32]: Remainder, [31:0]: Quotient

    logic is_signed;
    logic a_neg;
    logic b_neg;
    logic div_by_zero;
    logic overflow;
    logic is_rem;

    assign is_signed = (funct3 == FUNCT3_DIV) || (funct3 == FUNCT3_REM);
    assign is_rem    = (funct3 == FUNCT3_REM) || (funct3 == FUNCT3_REMU);

    logic [32:0] sub_res;
    assign sub_res = {1'b0, rem_quot[62:31]} - {1'b0, divisor};

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    always_comb begin
        case (state)
            IDLE:    next_state = start ? DIVIDE : IDLE;
            DIVIDE:  next_state = (count == 5'd31) ? FINISH : DIVIDE;
            FINISH:  next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count       <= 5'd0;
            divisor     <= 32'd0;
            rem_quot    <= 64'd0;
            a_neg       <= 1'b0;
            b_neg       <= 1'b0;
            div_by_zero <= 1'b0;
            overflow    <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        count <= 5'd0;

                        a_neg <= is_signed & a[31];
                        b_neg <= is_signed & b[31];

                        div_by_zero <= (b == 32'd0);
                        overflow    <= is_signed & (a == 32'h80000000) & (b == 32'hFFFFFFFF);

                        rem_quot <= {32'd0, (is_signed & a[31]) ? -a : a};
                        divisor  <= (is_signed & b[31]) ? -b : b;
                    end
                end

                DIVIDE: begin
                    count <= count + 5'd1;
                    if (!sub_res[32]) begin
                        rem_quot <= {sub_res[31:0], rem_quot[30:0], 1'b1};
                    end else begin
                        rem_quot <= {rem_quot[62:0], 1'b0};
                    end
                end

                FINISH: begin
                end
            endcase
        end
    end

    logic [31:0] final_quot;
    logic [31:0] final_rem;

    always_comb begin
        final_quot = (a_neg ^ b_neg) ? -rem_quot[31:0] : rem_quot[31:0];
        final_rem  = a_neg ? -rem_quot[63:32] : rem_quot[63:32];

        if (div_by_zero) begin
            final_quot = 32'hFFFFFFFF;
            final_rem  = a;
        end else if (overflow) begin
            final_quot = 32'h80000000;
            final_rem  = 32'd0;
        end

        result = is_rem ? final_rem : final_quot;
    end

    assign busy = (state == DIVIDE) || (state == FINISH);
    assign done = (state == FINISH);

endmodule
