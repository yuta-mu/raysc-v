`include "rv32i_types.svh"

module cpu #(
    parameter bit ENABLE_M       = 1'b1,
    parameter bit ENABLE_CUSTOM0 = 1'b0
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

    // H-1: 停止及びパフォーマンスカウンタ
    output logic        halted,
    output logic [63:0] cycles,
    output logic [63:0] instret,

    output logic        retire
);

    // Interconnecting control signals
    logic        branch_en;
    logic        jump;
    result_src_t result_src;
    alu_op_t     alu_op;
    logic        alu_src_a;
    logic        alu_src_b;
    logic        reg_write_ctrl;
    logic        mem_write_ctrl;
    logic        mem_read_ctrl;
    logic        is_ebreak;
    logic        stall;
    logic        mem_stall;
    logic        inst_valid;

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
        .mem_read   (mem_read_ctrl),
        .mem_write  (mem_write_ctrl),
        .result_src (result_src),
        .alu_src_a  (alu_src_a),
        .alu_src_b  (alu_src_b),
        .reg_write  (reg_write_ctrl),
        .alu_op     (alu_op)
    );

    typedef enum logic [1:0] {
        S_FETCH,   // BRAM Port A から inst が出力されるのを1サイクル待つ
        S_EXECUTE,
        S_MEM_WAIT // ロード命令時，BRAM Port B から データが出るのを1サイクル待つ
    } mem_state_t;

    mem_state_t mem_state;
    logic       halted_reg;

    assign inst_valid = (mem_state != S_FETCH);

    assign is_ebreak = (mem_state == S_EXECUTE) && (inst == 32'h0010_0073);

    // BRAM待ち
    // 1. 命令がまだ届いていない
    // 2. 実行中かつロード命令(データが次のS_MEM_WAIT で届く)
    assign mem_stall = (mem_state == S_FETCH) || (mem_state == S_EXECUTE && mem_read_ctrl);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_state <= S_FETCH;
        end else if (!halted_reg) begin
            case (mem_state)
                S_FETCH: mem_state <= S_EXECUTE;
                S_EXECUTE: begin
                    if      (is_ebreak)     mem_state <= S_EXECUTE;
                    else if (mem_read_ctrl) mem_state <= S_MEM_WAIT;
                    else if (!stall)        mem_state <= S_FETCH;
                end
                S_MEM_WAIT: mem_state <= S_FETCH;
                default: mem_state <= S_FETCH;
            endcase
        end
    end

    assign mem_read  = mem_read_ctrl && (mem_state == S_EXECUTE)
                       && !is_ebreak && !halted_reg;
    assign mem_write = mem_write_ctrl && (mem_state == S_EXECUTE) && !stall
                       && !is_ebreak && !halted_reg;

    // H-1: カウンタと停止
    assign halted = halted_reg;
    assign retire = !stall && !halted_reg && !is_ebreak;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycles     <= 64'd0;
            instret    <= 64'd0;
            halted_reg <= 1'b0;
        end else if (!halted_reg) begin
            cycles <= cycles + 64'd1;
            if (is_ebreak) begin
                 halted_reg <= 1'b1;
            end else if (retire) begin
                instret <= instret + 64'd1;
            end
        end
    end

    datapath u_datapath (
        .clk        (clk),
        .rst_n      (rst_n),
        .halted     (halted_reg),
        .inst_valid (inst_valid),
        .mem_stall  (mem_stall),
        .branch_en  (branch_en),
        .jump       (jump),
        .result_src (result_src),
        .alu_op     (alu_op),
        .alu_src_a  (alu_src_a),
        .alu_src_b  (alu_src_b),
        .reg_write  (reg_write_ctrl),
        .pc         (pc),
        .inst       (inst),
        .mem_addr   (mem_addr),
        .mem_wdata  (mem_wdata),
        .mem_wstrb  (mem_wstrb),
        .mem_rdata  (mem_rdata),
        .stall      (stall)
    );

endmodule

