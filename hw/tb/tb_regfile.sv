module tb_regfile;
    logic        clk;
    logic        reg_write;
    logic [4:0]  rs1_addr, rs2_addr, rd_addr;
    logic [31:0] wdata;
    logic [31:0] rs1_data, rs2_data;

    regfile dut (
        .clk(clk),
        .reg_write(reg_write),
        .rs1_addr(rs1_addr),
        .rs2_addr(rs2_addr),
        .rd_addr(rd_addr),
        .wdata(wdata),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("hw/sim/wave.vcd");
        $dumpvars(0, tb_regfile);

        clk = 0;
        reg_write = 0;
        rs1_addr = 0;
        rs2_addr = 0;
        rd_addr = 0;
        wdata = 0;
        #10;

        @(posedge clk);
        reg_write = 1;
        rd_addr = 5'd1;
        wdata = 32'hDEAD_BEEF;

        @(posedge clk);
        reg_write = 0;

        rs1_addr = 5'd1;
        #1;
        assert(rs1_data == 32'hDEAD_BEEF) else $fatal(1, "x1 write/read failed");

        @(posedge clk);
        reg_write = 1;
        rd_addr = 5'd0;
        wdata = 32'hCAFE_BABE;

        @(posedge clk);
        reg_write = 0;

        rs1_addr = 5'd0;
        #1;
        assert(rs1_data == 32'd0) else $fatal(1, "x0 must remain zero");

        $display("=== ALL REGFILE TESTS PASSED SUCCESSFULLY ===");
        $finish;
    end
endmodule

