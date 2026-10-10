`include "rv32i_types.svh"

module tb_alu;
    logic [31:0] a, b;
    alu_op_t     alu_op;
    logic [31:0] result;
    logic        zero;

    alu dut (
        .a(a),
        .b(b),
        .alu_op(alu_op),
        .result(result),
        .zero(zero)
    );

    initial begin
        $dumpfile("hw/sim/wave.vcd");
        $dumpvars(0, tb_alu);

        // ADD: 15 + 27 = 42
        a = 32'd15; b = 32'd27; alu_op = ALU_ADD; #10;
        assert(result == 32'd42 && zero == 0) else $fatal(1, "ADD failed");

        // SUB & Zero flag: 100 - 100 = 0
        a = 32'd100; b = 32'd100; alu_op = ALU_SUB; #10;
        assert(result == 32'd0 && zero == 1) else $fatal(1, "SUB Zero failed");

        // SLT: -5 < 3 -> 1
        a = -32'd5; b = 32'd3; alu_op = ALU_SLT; #10;
        assert(result == 32'd1) else $fatal(1, "SLT failed");

        // SLTU: -5 (0xFFFFFFFB) < 3 -> 0
        a = -32'd5; b = 32'd3; alu_op = ALU_SLTU; #10;
        assert(result == 32'd0) else $fatal(1, "SLTU failed");

        // SRA: -16 >>> 2 = -4
        a = -32'd16; b = 32'd2; alu_op = ALU_SRA; #10;
        assert(result == -32'd4) else $fatal(1, "SRA failed");

        // SRL: 0x80000000 >> 1 = 0x40000000
        a = 32'h8000_0000; b = 32'd1; alu_op = ALU_SRL; #10;
        assert(result == 32'h4000_0000) else $fatal(1, "SRL failed");

        $display("=== ALL ALU TESTS PASSED SUCCESSFULLY ===");
        $finish;
    end
endmodule

