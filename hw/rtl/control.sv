`include "rv32i_types.svh"

module control(
    input  opcode_t      opcode,
    input  logic [6:0]   funct7,
    output logic         branch_en,
    output logic         jump,
    output logic         mem_read,
    output logic         mem_write,
    output result_src_t  result_src,
    output alu_op_mode_t alu_op,
    output logic         alu_src_a, // 0: rs1, 1: pc
    output logic         alu_src_b, // 0: rs2, 1: imm
    output logic         reg_write
);

    always_comb begin
        // ラッチ防止
        branch_en  = 1'b0;
        jump       = 1'b0;
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        result_src = RESULT_ALU;
        alu_op     = ALU_OP_ADD;
        alu_src_a  = 1'b0;
        alu_src_b  = 1'b0;
        reg_write  = 1'b0;

        case (opcode)
            OP_REG: begin
                reg_write  = 1'b1;
                alu_src_a  = 1'b0; // rs1
                alu_src_b  = 1'b0; // rs2
                if (funct7 == 7'b0000001) begin
                    result_src = RESULT_MDU;
                    alu_op     = ALU_OP_ADD;
                end else begin
                    result_src = RESULT_ALU;
                    alu_op     = ALU_OP_RTYPE;
                end
            end

            OP_IMM: begin
                reg_write  = 1'b1;
                alu_src_a  = 1'b0; // rs1
                alu_src_b  = 1'b1; // imm
                result_src = RESULT_ALU;
                alu_op     = ALU_OP_ITYPE;
            end

            OP_LOAD: begin
                reg_write  = 1'b1;
                alu_src_a  = 1'b0; // rs1
                alu_src_b  = 1'b1; // imm
                mem_read   = 1'b1;
                result_src = RESULT_MEM;
                alu_op     = ALU_OP_ADD;
            end

            OP_STORE: begin
                alu_src_a  = 1'b0; // rs1
                alu_src_b  = 1'b1; // imm
                mem_write  = 1'b1;
                alu_op     = ALU_OP_ADD;
            end

            OP_BRANCH: begin
                branch_en  = 1'b1;
                alu_src_a  = 1'b0; // rs1
                alu_src_b  = 1'b0; // rs2
                alu_op     = ALU_OP_BRANCH;
            end

            OP_JAL: begin
                reg_write  = 1'b1;
                jump       = 1'b1;
                result_src = RESULT_PC4;
            end

            OP_JALR: begin
                reg_write  = 1'b1;
                jump       = 1'b1;
                alu_src_a  = 1'b0; // rs1
                alu_src_b  = 1'b1; // imm
                result_src = RESULT_PC4;
                alu_op     = ALU_OP_ADD;
            end

            OP_LUI: begin
                reg_write  = 1'b1;
                result_src = RESULT_IMM;
            end

            OP_AUIPC: begin
                reg_write  = 1'b1;
                alu_src_a  = 1'b1; // pc
                alu_src_b  = 1'b1; // imm
                result_src = RESULT_ALU;
                alu_op     = ALU_OP_ADD;
            end

            default: ;
        endcase
    end
endmodule

