`include "rv32i_types.svh"

module tb_control;

    opcode_t      opcode;
    logic [2:0]   funct3;
    logic         funct7_5;

    // control.sv output
    logic         branch;
    logic         jump;
    logic         mem_read;
    logic         mem_write;
    result_src_t  result_src;
    alu_op_mode_t alu_op_mode;
    logic         alu_src;
    logic         reg_write;

    // alu_control.sv output
    alu_op_t      alu_ctrl;

    control u_control (
        .opcode     (opcode),
        .branch_en  (branch_en),
        .jump       (jump),
        .mem_read   (mem_read),
        .mem_write  (mem_write),
        .result_src (result_src),
        .alu_op     (alu_op_mode),
        .alu_src    (alu_src),
        .reg_write  (reg_write)
    );

    alu_control u_alu_control (
        .alu_op   (alu_op_mode),
        .funct3   (funct3),
        .funct7_5 (funct7_5),
        .alu_ctrl (alu_ctrl)
    );

    initial begin
        $dumpfile("hw/sim/wave.vcd");
        $dumpvars(0, tb_control);

        // ADD
        opcode = OP_REG; funct3 = FUNCT3_ADD; funct7_5 = 1'b0;
        #1;
        assert (reg_write == 1'b1 && alu_src == 1'b0 && alu_ctrl == ALU_ADD && result_src == RESULT_ALU)
            else $error("ADD test failed!");

        // SUB
        opcode = OP_REG; funct3 = FUNCT3_ADD; funct7_5 = 1'b1;
        #1;
        assert (reg_write == 1'b1 && alu_src == 1'b0 && alu_ctrl == ALU_SUB && result_src == RESULT_ALU)
            else $error("SUB test failed!");

        // ADDI
        opcode = OP_IMM; funct3 = FUNCT3_ADD; funct7_5 = 1'b0;
        #1;
        assert (reg_write == 1'b1 && alu_src == 1'b1 && alu_ctrl == ALU_ADD && result_src == RESULT_ALU)
            else $error("ADDI test failed!");

        // LW
        opcode = OP_LOAD; funct3 = FUNCT3_LW; funct7_5 = 1'b0;
        #1;
        assert (reg_write == 1'b1 && mem_read == 1'b1 && alu_src == 1'b1 && result_src == RESULT_MEM && alu_ctrl == ALU_ADD)
            else $error("LW test failed!");

        // SW
        opcode = OP_STORE; funct3 = FUNCT3_SW; funct7_5 = 1'b0;
        #1;
        assert (reg_write == 1'b0 && mem_write == 1'b1 && alu_src == 1'b1 && alu_ctrl == ALU_ADD)
            else $error("SW test failed!");

        // BEQ
        opcode = OP_BRANCH; funct3 = FUNCT3_BEQ; funct7_5 = 1'b0;
        #1;
        assert (branch == 1'b1 && reg_write == 1'b0 && alu_src == 1'b0 && alu_ctrl == ALU_SUB)
            else $error("BEQ test failed!");

        // JAL
        opcode = OP_JAL; funct3 = 3'b000; funct7_5 = 1'b0;
        #1;
        assert (jump == 1'b1 && reg_write == 1'b1 && result_src == RESULT_PC4)
            else $error("JAL test failed!");

        // JALR
        opcode = OP_JALR; funct3 = FUNCT3_JALR; funct7_5 = 1'b0;
        #1;
        assert (jump == 1'b1 && reg_write == 1'b1 && result_src == RESULT_PC4 && alu_src == 1'b1 && alu_ctrl == ALU_ADD)
            else $error("JALR test failed!");

        $display("=== ALL CONTROL TESTS PASSED ===");
        $finish;
    end

endmodule

