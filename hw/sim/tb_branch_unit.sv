`include "rv32i_types.svh"

module tb_branch_unit;
    logic [31:0] rs1_data;
    logic [31:0] rs2_data;
    logic [2:0]  funct3;
    logic        branch_en;
    logic        branch_taken;

    branch_unit dut (
        .rs1_data(rs1_data),
        .rs2_data(rs2_data),
        .funct3(funct3),
        .branch_en(branch_en),
        .branch_taken(branch_taken)
    );

    initial begin
        $dumpfile("hw/sim/wave.vcd");
        $dumpvars(0, tb_branch_unit);

        branch_en = 1'b1;

        // BEQ
        funct3 = FUNCT3_BEQ;
        rs1_data = 32'd10; rs2_data = 32'd10; #10;
        assert(branch_taken == 1'b1) else $fatal(1, "BEQ true failed");
        rs1_data = 32'd10; rs2_data = 32'd20; #10;
        assert(branch_taken == 1'b0) else $fatal(1, "BEQ false failed");

        // BNE
        funct3 = FUNCT3_BNE;
        rs1_data = 32'd10; rs2_data = 32'd20; #10;
        assert(branch_taken == 1'b1) else $fatal(1, "BNE true failed");
        funct3 = FUNCT3_BNE;
        rs1_data = 32'd10; rs2_data = 32'd10; #10;
        assert(branch_taken == 1'b0) else $fatal(1, "BNE flase failed");

        // BLT vs BLTU
        rs1_data = -32'd1;
        rs2_data = 32'd1;

        // signed: -1 < 1 -> True
        funct3 = FUNCT3_BLT; #10;
        assert(branch_taken == 1'b1) else $fatal(1, "BLT signed failed");

        // unsigned: 0xFFFFFFFF < 0x00000001 -> False
        funct3 = FUNCT3_BLTU; #10;
        assert(branch_taken == 1'b0) else $fatal(1, "BLTU unsigned failed");

        // BGE vs BGEU
        funct3 = FUNCT3_BGE; #10;
        assert(branch_taken == 1'b0) else $fatal(1, "BGE signed failed");

        funct3 = FUNCT3_BGEU; #10;
        assert(branch_taken == 1'b1) else $fatal(1, "BGEU unsigned failed");

        // branch_en = 0 のときは条件が合致しても taken にならないこと
        branch_en = 1'b0;
        funct3 = FUNCT3_BEQ;
        rs1_data = 32'd5; rs2_data = 32'd5; #10;
        assert(branch_taken == 1'b0) else $fatal(1, "branch_en gating failed");

        $display("=== ALL BRANCH_UNIT TESTS PASSED ===");
        $finish;
    end
endmodule

