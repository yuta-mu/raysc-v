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

    assign rs1_data = (rs1_addr == 0) ? 0 : rf[rs1_addr];
    assign rs2_data = (rs2_addr == 0) ? 0 : rf[rs2_addr];

    always_ff @(posedge clk) begin
        if (reg_write && (rd_addr != 0)) begin
            rf[rd_addr] <= wdata;
        end
    end

endmodule

