`include "rv32i_types.svh"

module branch_unit (
    input  logic [31:0] rs1_data,
    input  logic [31:0] rs2_data,
    input  logic [2:0]  funct3,
    input  logic        branch_en,
    output logic        branch_taken
);

    logic cond_met;
    assign branch_taken = branch_en & cond_met;

    always_comb begin
        case (funct3)
            FUNCT3_BEQ:  cond_met = (rs1_data == rs2_data);
            FUNCT3_BNE:  cond_met = (rs1_data != rs2_data);
            FUNCT3_BLT:  cond_met = ($signed(rs1_data) <  $signed(rs2_data));
            FUNCT3_BGE:  cond_met = ($signed(rs1_data) >= $signed(rs2_data));
            FUNCT3_BLTU: cond_met = (rs1_data <  rs2_data);
            FUNCT3_BGEU: cond_met = (rs1_data >= rs2_data);
            default:     cond_met = 1'b0;
        endcase
    end

endmodule

