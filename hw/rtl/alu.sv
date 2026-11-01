`include "rv32i_types.svh"

module alu (
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  alu_op_t     alu_op,
    output logic [31:0] result,
    output logic        zero
);

    wire [4:0] shamt = b[4:0];

    logic [4:0]  clz_n;
    logic [15:0] clz_v16;
    logic [7:0]  clz_v8;
    logic [3:0]  clz_v4;
    logic [1:0]  clz_v2;
    logic [31:0] clz_result;
    logic [31:0] sextb_result;
    logic [31:0] sexth_result;

    assign clz_n[4]   = (a[31:16] == 16'd0);
    assign clz_v16    = clz_n[4] ? a[15:0]      : a[31:16];

    assign clz_n[3]   = (clz_v16[15:8] == 8'd0);
    assign clz_v8     = clz_n[3] ? clz_v16[7:0] : clz_v16[15:8];

    assign clz_n[2]   = (clz_v8[7:4] == 4'd0);
    assign clz_v4     = clz_n[2] ? clz_v8[3:0]  : clz_v8[7:4];

    assign clz_n[1]   = (clz_v4[3:2] == 2'd0);
    assign clz_v2     = clz_n[1] ? clz_v4[1:0]  : clz_v4[3:2];

    assign clz_n[0]   = ~clz_v2[1];
    assign clz_result = (a == 32'd0) ? 32'd32 : {27'd0, clz_n};

    // --- Zbb: sext.b / sext.h ---
    assign sextb_result = {{24{a[7]}},  a[7:0]};
    assign sexth_result = {{16{a[15]}}, a[15:0]};

    assign zero = (result == 32'd0);

    always_comb begin
        case (alu_op)
            ALU_ADD:   result = a + b;
            ALU_SUB:   result = a - b;
            ALU_SLL:   result = a << shamt;
            ALU_SLT:   result = 32'($signed(a) < $signed(b));
            ALU_SLTU:  result = 32'(a < b);
            ALU_XOR:   result = a ^ b;
            ALU_SRL:   result = a >> shamt;
            ALU_SRA:   result = $signed(a) >>> shamt;
            ALU_OR:    result = a | b;
            ALU_AND:   result = a & b;

            ALU_MIN:   result = ($signed(a) < $signed(b)) ? a : b;
            ALU_MAX:   result = ($signed(a) < $signed(b)) ? b : a;
            ALU_MINU:  result = (a < b)                   ? a : b;
            ALU_MAXU:  result = (a < b)                   ? b : a;

            ALU_ANDN:  result = a & ~b;
            ALU_ORN:   result = a | ~b;
            ALU_XNOR:  result = ~(a ^ b);

            ALU_ZBB_UNARY: begin
                case (shamt)
                    SHAMT_ZBB_CLZ:   result = clz_result;
                    SHAMT_ZBB_SEXTB: result = sextb_result;
                    SHAMT_ZBB_SEXTH: result = sexth_result;
                    default:         result = 32'd0;
                endcase
            end

            default:   result = 32'd0;
        endcase
    end

endmodule

