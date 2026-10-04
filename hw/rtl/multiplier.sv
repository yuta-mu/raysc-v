`include "rv32i_types.svh"

module multiplier (
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  logic [2:0]  funct3,
    output logic [31:0] result
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

    logic signed [32:0] op_a;
    logic signed [32:0] op_b;

    assign op_a = {a_signed & a[31], a};
    assign op_b = {b_signed & b[31], b};

    logic signed [65:0] prod;
    assign prod = op_a * op_b;

    always_comb begin
        if (funct3 == FUNCT3_MUL) begin
            result = prod[31:0];
        end else begin
            result = prod[63:32];
        end
    end

endmodule
