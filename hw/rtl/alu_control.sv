`include "rv32i_types.svh"

module alu_control (
    input  alu_op_mode_t alu_op,
    input  logic [2:0]   funct3,
    input  logic [6:0]   funct7,
    output alu_op_t      alu_ctrl
);

    wire funct7_5 = funct7[5]; // inst[30]

    always_comb begin
        alu_ctrl = ALU_ADD;

        case (alu_op)
            ALU_OP_ADD:    alu_ctrl = ALU_ADD;
            ALU_OP_BRANCH: alu_ctrl = ALU_SUB;

            ALU_OP_RTYPE: begin
                if (funct7 == FUNCT7_ZBB_MINMAX) begin
                    case (funct3)
                        FUNCT3_MIN:   alu_ctrl = ALU_MIN;
                        FUNCT3_MINU:  alu_ctrl = ALU_MINU;
                        FUNCT3_MAX:   alu_ctrl = ALU_MAX;
                        FUNCT3_MAXU:  alu_ctrl = ALU_MAXU;
                        default: ;
                    endcase
                end else begin
                    case (funct3)
                        FUNCT3_ADD:  alu_ctrl = alu_op_t'(funct7_5 ? ALU_SUB  : ALU_ADD);
                        FUNCT3_SLL:  alu_ctrl = ALU_SLL;
                        FUNCT3_SLT:  alu_ctrl = ALU_SLT;
                        FUNCT3_SLTU: alu_ctrl = ALU_SLTU;
                        FUNCT3_XOR:  alu_ctrl = alu_op_t'(funct7_5 ? ALU_XNOR : ALU_XOR);
                        FUNCT3_SRL:  alu_ctrl = alu_op_t'(funct7_5 ? ALU_SRA  : ALU_SRL);
                        FUNCT3_OR:   alu_ctrl = alu_op_t'(funct7_5 ? ALU_ORN  : ALU_OR);
                        FUNCT3_AND:  alu_ctrl = alu_op_t'(funct7_5 ? ALU_ANDN : ALU_AND);
                        default: ;
                    endcase
                end
            end

            ALU_OP_ITYPE: begin
                case (funct3)
                    FUNCT3_ADDI:  alu_ctrl = ALU_ADD;
                    FUNCT3_SLLI:  alu_ctrl = alu_op_t'((funct7 == FUNCT7_ZBB_UNARY) ? ALU_ZBB_UNARY : ALU_SLL);
                    FUNCT3_SLTI:  alu_ctrl = ALU_SLT;
                    FUNCT3_SLTIU: alu_ctrl = ALU_SLTU;
                    FUNCT3_XORI:  alu_ctrl = ALU_XOR;
                    FUNCT3_SRLI:  alu_ctrl = alu_op_t'(funct7_5 ? ALU_SRA : ALU_SRL);
                    FUNCT3_ORI:   alu_ctrl = ALU_OR;
                    FUNCT3_ANDI:  alu_ctrl = ALU_AND;
                    default: ;
                endcase
            end

            default: ;
        endcase
    end

endmodule

