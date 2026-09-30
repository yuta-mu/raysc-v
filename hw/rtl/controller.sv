`include "rv32i_types.svh"

module controller (
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

    control u_control (
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

    alu_control u_alu_control (
        .alu_op   (alu_op_mode),
        .funct3   (funct3),
        .funct7_5 (funct7[5]),
        .alu_ctrl (alu_op)
    );

endmodule

