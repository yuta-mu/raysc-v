`include "rv32i_types.svh"

module multiplier_pipe (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        valid,
    input  logic        stall_mem,
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  logic [2:0]  funct3,
    output logic [31:0] result,
    output logic        stall
);

    logic a_signed;
    logic b_signed;

    always_comb begin
        case (funct3)
            FUNCT3_MUL: begin
                a_signed = 1'b0;
                b_signed = 1'b0;
            end
            FUNCT3_MULH: begin
                a_signed = 1'b1;
                b_signed = 1'b1;
            end
            FUNCT3_MULHSU: begin
                a_signed = 1'b1;
                b_signed = 1'b0;
            end
            FUNCT3_MULHU: begin
                a_signed = 1'b0;
                b_signed = 1'b0;
            end
            default: begin
                a_signed = 1'b0;
                b_signed = 1'b0;
            end
        endcase
    end

    logic signed [32:0] op_a_in;
    logic signed [32:0] op_b_in;

    assign op_a_in = $signed({a_signed & a[31], a});
    assign op_b_in = $signed({b_signed & b[31], b});

    typedef enum logic [1:0] {
        MUL_IDLE = 2'd0,
        MUL_CALC = 2'd1,
        MUL_DONE = 2'd2
    } state_t;

    state_t state;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= MUL_IDLE;
        end else begin
            case (state)
                MUL_IDLE: if (valid && !stall_mem) state <= MUL_CALC;
                MUL_CALC:                          state <= MUL_DONE;
                MUL_DONE: if (!stall_mem)          state <= MUL_IDLE;
                default:                           state <= MUL_IDLE;
            endcase
        end
    end

    // データ・部分積レジスタは非同期リセットを持たせず DSP48E1 (AREG/BREG/MREG) へのパックを促進
    logic signed [32:0] op_a_r;
    logic signed [32:0] op_b_r;
    logic               is_low_r;

    wire signed [17:0] a_lo_s = $signed({1'b0, op_a_r[16:0]});
    wire signed [15:0] a_hi_s = $signed(op_a_r[32:17]);
    wire signed [17:0] b_lo_s = $signed({1'b0, op_b_r[16:0]});
    wire signed [15:0] b_hi_s = $signed(op_b_r[32:17]);

    (* use_dsp = "yes" *) logic signed [35:0] p_ll_r;
    (* use_dsp = "yes" *) logic signed [33:0] p_lh_r;
    (* use_dsp = "yes" *) logic signed [33:0] p_hl_r;
    (* use_dsp = "yes" *) logic signed [31:0] p_hh_r;

    always_ff @(posedge clk) begin
        if (state == MUL_IDLE && valid && !stall_mem) begin
            op_a_r   <= op_a_in;
            op_b_r   <= op_b_in;
            is_low_r <= (funct3 == FUNCT3_MUL);
        end
        if (state == MUL_CALC) begin
            p_ll_r <= a_lo_s * b_lo_s;
            p_lh_r <= a_lo_s * b_hi_s;
            p_hl_r <= a_hi_s * b_lo_s;
            p_hh_r <= a_hi_s * b_hi_s;
        end
    end

    logic signed [65:0] term_ll, term_lh, term_hl, term_hh, prod;

    assign term_ll = $signed({{30{p_ll_r[35]}}, p_ll_r});
    assign term_lh = $signed({{15{p_lh_r[33]}}, p_lh_r, 17'd0});
    assign term_hl = $signed({{15{p_hl_r[33]}}, p_hl_r, 17'd0});
    assign term_hh = $signed({p_hh_r, 34'd0});
    assign prod    = term_ll + term_lh + term_hl + term_hh;

    assign result = is_low_r ? prod[31:0] : prod[63:32];
    assign stall  = valid && (state != MUL_DONE);

endmodule
