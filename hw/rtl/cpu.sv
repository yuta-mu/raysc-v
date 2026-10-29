`include "rv32i_types.svh"

module cpu #(
    parameter bit ENABLE_M       = 1'b1,
    parameter bit ENABLE_CUSTOM0 = 1'b1
)(
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
    input  logic [31:0] mem_rdata,

    input  logic        uart_stall,

    // H-1: 停止及びパフォーマンスカウンタ
    output logic        halted,
    output logic [63:0] cycles,
    output logic [63:0] instret,

    output logic        retire
);

    // IDステージの命令とデコード信号
    logic [31:0] id_inst;
    opcode_t     opcode;
    logic [2:0]  funct3;
    logic [6:0]  funct7;

    assign opcode = opcode_t'(id_inst[6:0]);
    assign funct3 = id_inst[14:12];
    assign funct7 = id_inst[31:25];

    // Controller 出力
    logic        branch_en;
    logic        jump;
    logic        mem_read_ctrl;
    logic        mem_write_ctrl;
    result_src_t result_src;
    alu_op_t     alu_op;
    logic        alu_src_a;
    logic        alu_src_b;
    logic        reg_write_ctrl;

    controller u_controller (
        .*,
        .mem_read  (mem_read_ctrl),
        .mem_write (mem_write_ctrl),
        .reg_write (reg_write_ctrl)
    );

    // WBステージ完了・停止通知
    logic halted_reg;
    logic wb_retire;
    logic wb_ebreak;

    assign halted = halted_reg;
    assign retire = wb_retire;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycles     <= 64'd0;
            instret    <= 64'd0;
            halted_reg <= 1'b0;
        end else if (!halted_reg) begin
            cycles <= cycles + 64'd1;
            if (wb_ebreak) begin
                halted_reg <= 1'b1;
            end else if (wb_retire) begin
                instret <= instret + 64'd1;
            end
        end
    end

    datapath u_datapath (
        .clk            (clk),
        .rst_n          (rst_n),
        .halted         (halted_reg),
        .uart_stall     (uart_stall),
        .id_inst_out    (id_inst),
        .branch_en      (branch_en),
        .jump           (jump),
        .mem_read_ctrl  (mem_read_ctrl),
        .mem_write_ctrl (mem_write_ctrl),
        .result_src     (result_src),
        .alu_op         (alu_op),
        .alu_src_a      (alu_src_a),
        .alu_src_b      (alu_src_b),
        .reg_write      (reg_write_ctrl),
        .pc             (pc),
        .inst           (inst),
        .mem_read       (mem_read),
        .mem_write      (mem_write),
        .mem_addr       (mem_addr),
        .mem_wdata      (mem_wdata),
        .mem_wstrb      (mem_wstrb),
        .mem_rdata      (mem_rdata),
        .wb_retire      (wb_retire),
        .wb_ebreak      (wb_ebreak)
    );

endmodule

