`include "rv32i_types.svh"

module datapath (
    input  logic        clk,
    input  logic        rst_n,

    // H-1: CPU停止状態入力
    input  logic        halted,

    // UART ストール入力
    input  logic        uart_stall,

    // IDステージの命令出力（cpu.sv 内の controller でデコードするため）
    output logic [31:0] id_inst_out,

    // Controls from controller (IDステージ用)
    input  logic        branch_en,
    input  logic        jump,
    input  logic        mem_read_ctrl,
    input  logic        mem_write_ctrl,
    input  result_src_t result_src,
    input  alu_op_t     alu_op,
    input  logic        alu_src_a,
    input  logic        alu_src_b,
    input  logic        reg_write,

    // Memory bus
    output logic [31:0] pc,
    input  logic [31:0] inst,
    output logic        mem_read,
    output logic        mem_write,
    output logic [31:0] mem_addr,
    output logic [31:0] mem_wdata,
    output logic [3:0]  mem_wstrb,
    input  logic [31:0] mem_rdata,

    // WBステージ完了通知（cpu.sv のカウンタ・停止制御用）
    output logic        wb_retire,
    output logic        wb_ebreak
);

    // # パイプライン制御信号（Stall / Flush）の宣言
    logic stall_if, stall_id, stall_ex, stall_mem;
    logic branch_flush;
    logic load_use_stall;
    logic ex_busy_stall;
    logic ebreak_in_pipe;

    logic        ex_valid;
    logic        ex_is_ebreak;
    logic [31:0] ex_pc;
    logic [31:0] ex_pc_target;
    logic        ex_pc_src;

    // # Stage 1: IF (Instruction Fetch)
    logic [31:0] pc_next;
    logic [31:0] pc_plus4;

    assign pc_plus4 = pc + 32'd4;
    assign pc_next  = branch_flush ? ex_pc_target : pc_plus4;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= 32'h0000_0000;
        end else if (!halted) begin
            if (ex_valid && ex_is_ebreak) begin
                // 規則1 & 3: 有効な ebreak が EX に到達したら停止 PC を ebreak 自身のアドレスに固定
                pc <= ex_pc;
            end else if (!ebreak_in_pipe && (!stall_if || branch_flush)) begin
                pc <= pc_next;
            end
        end
    end

    // --- IF/ID パイプラインレジスタ & BRAM 出力退避バッファ (Skid Buffer) ---
    logic        id_valid;
    logic [31:0] id_pc;
    logic [31:0] id_pc_plus4;
    logic        inst_saved_valid;
    logic [31:0] inst_saved_data;
    logic [31:0] id_inst;

    assign id_inst     = inst_saved_valid ? inst_saved_data : inst;
    assign id_inst_out = id_inst;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            id_valid         <= 1'b0;
            id_pc            <= 32'h0;
            id_pc_plus4      <= 32'h0;
            inst_saved_valid <= 1'b0;
            inst_saved_data  <= 32'h0;
        end else if (halted || branch_flush || ebreak_in_pipe) begin
            id_valid         <= 1'b0;
            inst_saved_valid <= 1'b0;
        end else if (stall_id) begin
            if (!inst_saved_valid) begin
                inst_saved_valid <= 1'b1;
                inst_saved_data  <= inst;
            end
        end else begin
            id_valid         <= 1'b1;
            id_pc            <= pc;
            id_pc_plus4      <= pc_plus4;
            inst_saved_valid <= 1'b0;
        end
    end

    // # Stage 2: ID (Instruction Decode & Register File Read)
    logic [4:0]  id_rs1, id_rs2, id_rd;
    logic [2:0]  id_funct3;
    opcode_t     id_opcode;
    logic [31:0] id_rs1_data, id_rs2_data, id_imm;
    logic        id_is_ebreak;
    logic        id_uses_rs1, id_uses_rs2;

    assign id_opcode    = opcode_t'(id_inst[6:0]);
    assign id_rd        = id_inst[11:7];
    assign id_funct3    = id_inst[14:12];
    assign id_rs1       = id_inst[19:15];
    assign id_rs2       = id_inst[24:20];
    assign id_is_ebreak = id_valid && (id_inst == 32'h0010_0073);

    assign id_uses_rs1 = (id_opcode != OP_LUI) && (id_opcode != OP_AUIPC) && (id_opcode != OP_JAL);
    assign id_uses_rs2 = (id_opcode == OP_REG) || (id_opcode == OP_STORE) ||
                         (id_opcode == OP_BRANCH) || (id_opcode == OP_CUSTOM0);

    logic        wb_valid;
    logic        wb_reg_write;
    logic [4:0]  wb_rd;
    logic [31:0] wb_result_data;

    regfile u_regfile (
        .clk       (clk),
        .reg_write (wb_valid && wb_reg_write && !halted),
        .rs1_addr  (id_rs1),
        .rs2_addr  (id_rs2),
        .rd_addr   (wb_rd),
        .wdata     (wb_result_data),
        .rs1_data  (id_rs1_data),
        .rs2_data  (id_rs2_data)
    );

    imm_gen u_imm_gen (
        .inst (id_inst),
        .imm  (id_imm)
    );

    // --- ID/EX パイプラインレジスタ ---
    logic [31:0] ex_pc_plus4;
    logic [31:0] ex_rs1_data;
    logic [31:0] ex_rs2_data;
    logic [31:0] ex_imm;
    logic [4:0]  ex_rs1, ex_rs2, ex_rd;
    logic [2:0]  ex_funct3;

    logic        ex_branch_en;
    logic        ex_jump;
    logic        ex_mem_read;
    logic        ex_mem_write;
    result_src_t ex_result_src;
    alu_op_t     ex_alu_op;
    logic        ex_alu_src_a;
    logic        ex_alu_src_b;
    logic        ex_reg_write;

    logic [31:0] rs1_fwd, rs2_fwd;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ex_valid      <= 1'b0;
            ex_is_ebreak  <= 1'b0;
            ex_pc         <= 32'h0;
            ex_pc_plus4   <= 32'h0;
            ex_rs1_data   <= 32'h0;
            ex_rs2_data   <= 32'h0;
            ex_imm        <= 32'h0;
            ex_rs1        <= 5'd0;
            ex_rs2        <= 5'd0;
            ex_rd         <= 5'd0;
            ex_funct3     <= 3'd0;
            ex_branch_en  <= 1'b0;
            ex_jump       <= 1'b0;
            ex_mem_read   <= 1'b0;
            ex_mem_write  <= 1'b0;
            ex_result_src <= RESULT_ALU;
            ex_alu_op     <= ALU_ADD;
            ex_alu_src_a  <= 1'b0;
            ex_alu_src_b  <= 1'b0;
            ex_reg_write  <= 1'b0;
        end else if (stall_ex) begin
            ex_rs1_data <= rs1_fwd;
            ex_rs2_data <= rs2_fwd;
            ex_rs1      <= 5'd0;
            ex_rs2      <= 5'd0;
        end else if (halted || branch_flush || load_use_stall || ebreak_in_pipe || !id_valid) begin
            ex_valid      <= 1'b0;
            ex_is_ebreak  <= 1'b0;
            ex_branch_en  <= 1'b0;
            ex_jump       <= 1'b0;
            ex_mem_read   <= 1'b0;
            ex_mem_write  <= 1'b0;
            ex_reg_write  <= 1'b0;
        end else begin
            ex_valid      <= 1'b1;
            ex_is_ebreak  <= id_is_ebreak;
            ex_pc         <= id_pc;
            ex_pc_plus4   <= id_pc_plus4;
            ex_rs1_data   <= id_rs1_data;
            ex_rs2_data   <= id_rs2_data;
            ex_imm        <= id_imm;
            ex_rs1        <= id_rs1;
            ex_rs2        <= id_rs2;
            ex_rd         <= id_rd;
            ex_funct3     <= id_funct3;
            ex_branch_en  <= id_is_ebreak ? 1'b0 : branch_en;
            ex_jump       <= id_is_ebreak ? 1'b0 : jump;
            ex_mem_read   <= id_is_ebreak ? 1'b0 : mem_read_ctrl;
            ex_mem_write  <= id_is_ebreak ? 1'b0 : mem_write_ctrl;
            ex_result_src <= result_src;
            ex_alu_op     <= alu_op;
            ex_alu_src_a  <= alu_src_a;
            ex_alu_src_b  <= alu_src_b;
            ex_reg_write  <= id_is_ebreak ? 1'b0 : reg_write;
        end
    end

    // # Stage 3: EX (Execute & Forwarding & Multi-cycle Units)
    logic        mem_valid;
    logic        mem_reg_write;
    logic [4:0]  mem_rd;
    logic [31:0] mem_exec_result;

    always_comb begin
        if (mem_valid && mem_reg_write && (mem_rd != 5'd0) && (mem_rd == ex_rs1)) begin
            rs1_fwd = mem_exec_result;
        end else if (wb_valid && wb_reg_write && (wb_rd != 5'd0) && (wb_rd == ex_rs1)) begin
            rs1_fwd = wb_result_data;
        end else begin
            rs1_fwd = ex_rs1_data;
        end

        if (mem_valid && mem_reg_write && (mem_rd != 5'd0) && (mem_rd == ex_rs2)) begin
            rs2_fwd = mem_exec_result;
        end else if (wb_valid && wb_reg_write && (wb_rd != 5'd0) && (wb_rd == ex_rs2)) begin
            rs2_fwd = wb_result_data;
        end else begin
            rs2_fwd = ex_rs2_data;
        end
    end

    // --- ALU ---
    logic [31:0] alu_src_a_data, alu_src_b_data, ex_alu_result;
    assign alu_src_a_data = ex_alu_src_a ? ex_pc  : rs1_fwd;
    assign alu_src_b_data = ex_alu_src_b ? ex_imm : rs2_fwd;

    alu u_alu (
        .a      (alu_src_a_data),
        .b      (alu_src_b_data),
        .alu_op (ex_alu_op),
        .result (ex_alu_result),
        .zero   ()
    );

    // --- 分岐・ジャンプ判定 ---
    logic ex_branch_taken;
    branch_unit u_branch_unit (
        .rs1_data     (rs1_fwd),
        .rs2_data     (rs2_fwd),
        .funct3       (ex_funct3),
        .branch_en    (ex_valid && ex_branch_en),
        .branch_taken (ex_branch_taken)
    );

    assign ex_pc_target = (ex_jump && ex_alu_src_b) ? (ex_alu_result & ~32'd1) : (ex_pc + ex_imm);
    assign ex_pc_src    = ex_valid && (ex_jump || ex_branch_taken);

    // --- M拡張: 乗算器 (DSP直結パス切断のため1サイクルラッチ) & 除算器 ---
    logic [31:0] ex_mul_comb, ex_mul_q, ex_div_result, ex_mdu_result;
    logic        is_mul_op, mul_done_q, mul_stall;
    logic        div_busy, div_done, is_div_op, div_start, div_stall;

    multiplier u_multiplier (
        .a      (rs1_fwd),
        .b      (rs2_fwd),
        .funct3 (ex_funct3),
        .result (ex_mul_comb)
    );

    assign is_mul_op = ex_valid && (ex_result_src == RESULT_MDU) && !ex_funct3[2] && !halted;
    assign mul_stall = is_mul_op && !mul_done_q;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mul_done_q <= 1'b0;
            ex_mul_q   <= 32'h0;
        end else if (is_mul_op && !mul_done_q && !stall_mem) begin
            mul_done_q <= 1'b1;
            ex_mul_q   <= ex_mul_comb;
        end else if (!stall_mem) begin
            mul_done_q <= 1'b0;
        end
    end

    assign is_div_op = ex_valid && (ex_result_src == RESULT_MDU) && ex_funct3[2] && !halted;
    assign div_start = is_div_op && !div_busy && !div_done && !stall_mem;
    assign div_stall = is_div_op && !div_done;

    divider u_divider (
        .clk    (clk),
        .rst_n  (rst_n),
        .start  (div_start),
        .funct3 (ex_funct3),
        .a      (rs1_fwd),
        .b      (rs2_fwd),
        .result (ex_div_result),
        .busy   (div_busy),
        .done   (div_done)
    );

    assign ex_mdu_result = ex_funct3[2] ? ex_div_result : ex_mul_q;

    // --- custom-0 演算器 (qmul 含めすべて custom0.sv 内部で FF 出力化済み) ---
    logic        is_custom0, c0_stall;
    logic [31:0] ex_c0_result;

    assign is_custom0 = ex_valid && (ex_result_src == RESULT_C0) && !halted && !stall_mem;

    custom0 u_custom0 (
        .clk    (clk),
        .rst_n  (rst_n),
        .valid  (is_custom0),
        .a      (rs1_fwd),
        .b      (rs2_fwd),
        .funct3 (ex_funct3),
        .result (ex_c0_result),
        .stall  (c0_stall)
    );

    // --- EXステージ演算結果の統合 ---
    logic [31:0] ex_exec_result;
    always_comb begin
        case (ex_result_src)
            RESULT_ALU: ex_exec_result = ex_alu_result;
            RESULT_PC4: ex_exec_result = ex_pc_plus4;
            RESULT_IMM: ex_exec_result = ex_imm;
            RESULT_MDU: ex_exec_result = ex_mdu_result;
            RESULT_C0:  ex_exec_result = ex_c0_result;
            default:    ex_exec_result = ex_alu_result;
        endcase
    end

    // --- EX/MEM パイプラインレジスタ ---
    logic        mem_is_ebreak;
    logic        mem_mem_read;
    logic        mem_mem_write;
    result_src_t mem_result_src;
    logic [31:0] mem_rs2_data;
    logic [2:0]  mem_funct3;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_valid       <= 1'b0;
            mem_is_ebreak   <= 1'b0;
            mem_mem_read    <= 1'b0;
            mem_mem_write   <= 1'b0;
            mem_result_src  <= RESULT_ALU;
            mem_reg_write   <= 1'b0;
            mem_exec_result <= 32'h0;
            mem_rs2_data    <= 32'h0;
            mem_rd          <= 5'd0;
            mem_funct3      <= 3'd0;
        end else if (stall_mem) begin
            // UARTストール中はMEMステージを保持
        end else if (halted || ex_busy_stall || !ex_valid) begin
            mem_valid      <= 1'b0;
            mem_is_ebreak  <= 1'b0;
            mem_mem_read   <= 1'b0;
            mem_mem_write  <= 1'b0;
            mem_reg_write  <= 1'b0;
        end else begin
            mem_valid       <= 1'b1;
            mem_is_ebreak   <= ex_is_ebreak;
            mem_mem_read    <= ex_mem_read;
            mem_mem_write   <= ex_mem_write;
            mem_result_src  <= ex_result_src;
            mem_reg_write   <= ex_reg_write;
            mem_exec_result <= ex_exec_result;
            mem_rs2_data    <= rs2_fwd;
            mem_rd          <= ex_rd;
            mem_funct3      <= ex_funct3;
        end
    end

    // # Stage 4: MEM (Memory Access Request to BRAM Port B / MMIO / UART)
    assign mem_addr  = mem_exec_result;
    assign mem_read  = mem_valid && mem_mem_read  && !halted;
    assign mem_write = mem_valid && mem_mem_write && !halted;

    logic [1:0]  mem_byte_offset;
    logic [7:0]  rs2_b;
    logic [15:0] rs2_h;

    assign mem_byte_offset = mem_addr[1:0];
    assign rs2_b           = mem_rs2_data[7:0];
    assign rs2_h           = mem_rs2_data[15:0];

    always_comb begin
        case (mem_funct3)
            FUNCT3_SB: begin
                case (mem_byte_offset)
                    2'b00: begin mem_wdata = {24'b0, rs2_b};        mem_wstrb = 4'b0001; end
                    2'b01: begin mem_wdata = {16'b0, rs2_b, 8'b0};  mem_wstrb = 4'b0010; end
                    2'b10: begin mem_wdata = {8'b0,  rs2_b, 16'b0}; mem_wstrb = 4'b0100; end
                    2'b11: begin mem_wdata = {rs2_b, 24'b0};        mem_wstrb = 4'b1000; end
                endcase
            end
            FUNCT3_SH: begin
                if (mem_byte_offset[1]) begin
                    mem_wdata = {rs2_h, 16'b0};
                    mem_wstrb = 4'b1100;
                end else begin
                    mem_wdata = {16'b0, rs2_h};
                    mem_wstrb = 4'b0011;
                end
            end
            FUNCT3_SW: begin
                mem_wdata = mem_rs2_data;
                mem_wstrb = 4'b1111;
            end
            default: begin
                mem_wdata = mem_rs2_data;
                mem_wstrb = 4'b1111;
            end
        endcase
    end

    // --- MEM/WB パイプラインレジスタ ---
    logic        wb_is_ebreak;
    result_src_t wb_result_src;
    logic [31:0] wb_exec_result;
    logic [2:0]  wb_funct3;
    logic [1:0]  wb_byte_offset;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wb_valid       <= 1'b0;
            wb_is_ebreak   <= 1'b0;
            wb_result_src  <= RESULT_ALU;
            wb_reg_write   <= 1'b0;
            wb_exec_result <= 32'h0;
            wb_rd          <= 5'd0;
            wb_funct3      <= 3'd0;
            wb_byte_offset <= 2'd0;
        end else if (halted || stall_mem || !mem_valid) begin
            wb_valid      <= 1'b0;
            wb_is_ebreak  <= 1'b0;
            wb_reg_write  <= 1'b0;
        end else begin
            wb_valid       <= 1'b1;
            wb_is_ebreak   <= mem_is_ebreak;
            wb_result_src  <= mem_result_src;
            wb_reg_write   <= mem_reg_write;
            wb_exec_result <= mem_exec_result;
            wb_rd          <= mem_rd;
            wb_funct3      <= mem_funct3;
            wb_byte_offset <= mem_byte_offset;
        end
    end

    // # Stage 5: WB (Write Back & Load Data Alignment)
    logic [7:0]  rdata_b0, rdata_b1, rdata_b2, rdata_b3, selected_byte;
    logic [15:0] rdata_h0, rdata_h1, selected_half;
    logic        byte_sign, half_sign;
    logic [31:0] load_data;

    assign rdata_b0 = mem_rdata[7:0];
    assign rdata_b1 = mem_rdata[15:8];
    assign rdata_b2 = mem_rdata[23:16];
    assign rdata_b3 = mem_rdata[31:24];
    assign rdata_h0 = mem_rdata[15:0];
    assign rdata_h1 = mem_rdata[31:16];

    always_comb begin
        case (wb_byte_offset)
            2'b00: selected_byte = rdata_b0;
            2'b01: selected_byte = rdata_b1;
            2'b10: selected_byte = rdata_b2;
            2'b11: selected_byte = rdata_b3;
        endcase
    end

    assign selected_half = wb_byte_offset[1] ? rdata_h1 : rdata_h0;
    assign byte_sign     = selected_byte[7];
    assign half_sign     = selected_half[15];

    always_comb begin
        case (wb_funct3)
            FUNCT3_LB:  load_data = {{24{byte_sign}}, selected_byte};
            FUNCT3_LH:  load_data = {{16{half_sign}}, selected_half};
            FUNCT3_LW:  load_data = mem_rdata;
            FUNCT3_LBU: load_data = {24'b0, selected_byte};
            FUNCT3_LHU: load_data = {16'b0, selected_half};
            default:    load_data = mem_rdata;
        endcase
    end

    assign wb_result_data = (wb_result_src == RESULT_MEM) ? load_data : wb_exec_result;

    assign wb_retire = wb_valid && !wb_is_ebreak && !halted;
    assign wb_ebreak = wb_valid && wb_is_ebreak  && !halted;

    // # ハザード制御ユニット（Stall / Flush 統合）
    assign ex_busy_stall  = mul_stall || div_stall || c0_stall;
    assign load_use_stall = ex_valid && (ex_result_src == RESULT_MEM) && (ex_rd != 5'd0) &&
                            id_valid && ((id_uses_rs1 && (id_rs1 == ex_rd)) ||
                                         (id_uses_rs2 && (id_rs2 == ex_rd)));

    assign stall_mem = uart_stall && mem_valid && mem_mem_write;
    assign stall_ex  = stall_mem || ex_busy_stall;
    assign stall_id  = stall_ex  || load_use_stall;
    assign stall_if  = stall_id;

    assign branch_flush   = ex_pc_src && !stall_ex;
    assign ebreak_in_pipe = (ex_valid && ex_is_ebreak) ||
                            (mem_valid && mem_is_ebreak) ||
                            (wb_valid && wb_is_ebreak) || halted;

endmodule
