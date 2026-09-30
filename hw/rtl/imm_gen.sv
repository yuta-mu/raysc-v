`include "rv32i_types.svh"

module imm_gen (
    input  logic [31:0] inst,
    output logic [31:0] imm
);

    opcode_t opcode;
    assign opcode = opcode_t'(inst[6:0]);

    wire sign = inst[31];

    wire [11:0] imm_i = inst [31:20];
    wire [11:0] imm_s = {inst[31:25], inst[11:7]};
    wire [12:0] imm_b = {inst[31], inst[7], inst[30:25], inst[11:8], 1'b0};
    wire [31:0] imm_u = {inst[31:12], 12'b0};
    wire [20:0] imm_j = {inst[31], inst[19:12], inst[20], inst[30:21], 1'b0};

    always_comb begin
        case (opcode)
            OP_IMM, OP_LOAD, OP_JALR: imm = {{20{sign}}, imm_i};
            OP_STORE: imm = {{20{sign}}, imm_s};
            OP_BRANCH: imm = {{19{sign}}, imm_b};
            OP_LUI, OP_AUIPC: imm = imm_u;
            OP_JAL: imm = {{11{sign}}, imm_j};
            default:
                imm = 32'd0;
        endcase
    end

endmodule

