`include "rv32i_types.svh"

module cpu (
    input  logic        clk,
    input  logic        rst_n,

    // Instruction memory interface
    output logic [31:0] pc,
    input  logic [31:0] inst,

    // Data memory interface
    output logic        mem_read,
    output logic        mem_write,
    output logic [31:0] mem_addr,
    output logic [31:0] mem_wdata,
    output logic [3:0]  mem_wstrb,
    input  logic [31:0] mem_rdata
);

    // Interconnecting control signals
    logic        branch_en;
    logic        jump;
    result_src_t result_src;
    alu_op_t     alu_op;
    logic        alu_src_a;
    logic        alu_src_b;
    logic        reg_write;

    // Instruction fields for controller
    opcode_t     opcode;
    logic [2:0]  funct3;
    logic [6:0]  funct7;

    assign opcode = opcode_t'(inst[6:0]);
    assign funct3 = inst[14:12];
    assign funct7 = inst[31:25];

    controller u_controller (
        .opcode     (opcode),
        .funct3     (funct3),
        .funct7     (funct7),
        .branch_en  (branch_en),
        .jump       (jump),
        .mem_read   (mem_read),
        .mem_write  (mem_write),
        .result_src (result_src),
        .alu_src_a  (alu_src_a),
        .alu_src_b  (alu_src_b),
        .reg_write  (reg_write),
        .alu_op     (alu_op)
    );

    datapath u_datapath (
        .clk        (clk),
        .rst_n      (rst_n),
        .branch_en  (branch_en),
        .jump       (jump),
        .result_src (result_src),
        .alu_op     (alu_op),
        .alu_src_a  (alu_src_a),
        .alu_src_b  (alu_src_b),
        .reg_write  (reg_write),
        .pc         (pc),
        .inst       (inst),
        .mem_addr   (mem_addr),
        .mem_wdata  (mem_wdata),
        .mem_wstrb  (mem_wstrb),
        .mem_rdata  (mem_rdata)
    );

endmodule

