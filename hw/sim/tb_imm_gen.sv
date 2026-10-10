module tb_imm_gen;
    logic [31:0] inst;
    logic [31:0] imm;

    imm_gen dut (
        .inst(inst),
        .imm(imm)
    );

    initial begin
        $dumpfile("hw/sim/wave.vcd");
        $dumpvars(0, tb_imm_gen);

        // I-type (addi x1, x0, 1)
        inst = 32'h00100093; #10;
        assert(imm == 32'd1) else $fatal(1, "I-type positive failed");
        // I-type (addi x1, x0, -1)
        inst = 32'hFFF00093; #10;
        assert(imm == -32'd1) else $fatal(1, "I-type negative failed");
        // S-type (sw x2, -4(x1))
        inst = 32'hFE20AE23; #10;
        assert(imm == -32'd4) else $fatal(1, "S-type failed");
        // B-type (beq x1, x2, 16)
        inst = 32'h00208863; #10;
        assert(imm == 32'd16) else $fatal(1, "B-type positive failed");
        // B-type (beq x1, x2, -4)
        inst = 32'hFE208EE3; #10;
        assert(imm == -32'd4) else $fatal(1, "B-type negative failed");
        // U-type (lui x1, 0x12345)
        inst = 32'h123450B7; #10;
        assert(imm == 32'h1234_5000) else $fatal(1, "U-type failed");
        // J-type (jal x1, 2048)
        inst = 32'h001000EF; #10;
        assert(imm == 32'd2048) else $fatal(1, "J-type positive failed");
        // J-type (jal x0, -2)
        inst = 32'hFFFFF06F; #10;
        assert(imm == -32'd2) else $fatal(1, "J-type negative failed");

        $display("=== ALL IMM_GEN TESTS PASSED ===");
        $finish;
    end
endmodule

