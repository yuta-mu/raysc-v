`include "rv32i_types.svh"

module controller #(
    parameter bit ENABLE_M       = 1'b1,
    parameter bit ENABLE_ZBB     = 1'b1,
    parameter bit ENABLE_CUSTOM0 = 1'b1
)(
    input  opcode_t      opcode,
    input  logic [2:0]   funct3,
    input  logic [6:0]   funct7,

    // Controls to datapath
    output logic         branch_en,
    output logic         jump,
    output logic         mem_read,
    output logic         mem_write,
    output result_src_t  result_src,
    output logic         alu_src_a,
    output logic         alu_src_b,
    output logic         reg_write,
    output alu_op_t      alu_op
);

    alu_op_mode_t alu_op_mode;

    control #(
        .ENABLE_M       (ENABLE_M),
        .ENABLE_CUSTOM0 (ENABLE_CUSTOM0)
    ) u_control (
        .opcode     (opcode),
        .funct7     (funct7),
        .branch_en  (branch_en),
        .jump       (jump),
        .mem_read   (mem_read),
        .mem_write  (mem_write),
        .result_src (result_src),
        .alu_op     (alu_op_mode),
        .alu_src_a  (alu_src_a),
        .alu_src_b  (alu_src_b),
        .reg_write  (reg_write)
    );

    alu_control #(
        .ENABLE_ZBB (ENABLE_ZBB)
    ) u_alu_control (
        .alu_op   (alu_op_mode),
        .funct3   (funct3),
        .funct7   (funct7),
        .alu_ctrl (alu_op)
    );

endmodule

