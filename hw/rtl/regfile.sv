module regfile (
    input  logic        clk,
    input  logic        reg_write,
    input  logic [4:0]  rs1_addr,
    input  logic [4:0]  rs2_addr,
    input  logic [4:0]  rd_addr,
    input  logic [31:0] wdata,
    output logic [31:0] rs1_data,
    output logic [31:0] rs2_data
);

    logic [31:0] rf [31:0];

    // WBステージとIDステージが同一レジスタにアクセスした際の内部バイパス
    assign rs1_data = (rs1_addr == 5'd0) ? 32'd0 :
                      (reg_write && (rd_addr == rs1_addr)) ? wdata : rf[rs1_addr];

    assign rs2_data = (rs2_addr == 5'd0) ? 32'd0 :
                      (reg_write && (rd_addr == rs2_addr)) ? wdata : rf[rs2_addr];

    always_ff @(posedge clk) begin
        if (reg_write && (rd_addr != 5'd0)) begin
            rf[rd_addr] <= wdata;
        end
    end

endmodule

