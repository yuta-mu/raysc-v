`include "rv32i_types.svh"

module alu (
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  alu_op_t     alu_op,
    output logic [31:0] result,
    output logic        zero
);

    wire [4:0] shamt = b[4:0];

    assign zero = (result == 32'd0);

    always_comb begin
        case (alu_op)
            ALU_ADD:  result = a + b;
            ALU_SUB:  result = a - b;
            ALU_SLL:  result = a << shamt;
            ALU_SLT:  result = 32'($signed(a) < $signed(b));
            ALU_SLTU: result = 32'(a < b);
            ALU_XOR:  result = a ^ b;
            ALU_SRL:  result = a >> shamt;
            ALU_SRA:  result = $signed(a) >>> shamt;
            ALU_OR:   result = a | b;
            ALU_AND:  result = a & b;
            default:  result = 32'd0;
        endcase
    end

endmodule

