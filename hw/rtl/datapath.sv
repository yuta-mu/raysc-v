`include "rv32i_types.svh"

module datapath (
    input  logic        clk,
    input  logic        rst_n,

    // Controls from controller
    input  logic        branch_en,
    input  logic        jump,
    input  result_src_t result_src,
    input  alu_op_t     alu_op,
    input  logic        alu_src_a,
    input  logic        alu_src_b,
    input  logic        reg_write,

    // Memory bus
    output logic [31:0] pc,
    input  logic [31:0] inst,
    output logic [31:0] mem_addr,
    output logic [31:0] mem_wdata,
    output logic [3:0]  mem_wstrb,
    input  logic [31:0] mem_rdata
);

    logic [31:0] pc_next;
    logic [31:0] pc_plus4;
    logic [31:0] pc_target;
    logic        pc_src;

    logic [31:0] imm;
    logic [31:0] rs1_data;
    logic [31:0] rs2_data;
    logic [31:0] alu_src_a_data;
    logic [31:0] alu_src_b_data;
    logic [31:0] alu_result;
    logic [31:0] mul_result;
    logic [31:0] result_data;
    logic        branch_taken;

    logic [4:0]  rs1;
    logic [4:0]  rs2;
    logic [4:0]  rd;
    logic [2:0]  funct3;

    assign rs1    = inst[19:15];
    assign rs2    = inst[24:20];
    assign rd     = inst[11:7];
    assign funct3 = inst[14:12];

    // PC Logic
    assign pc_plus4  = pc + 32'd4;
    assign pc_target = (jump && alu_src_b) ? (alu_result & ~32'd1) : (pc + imm); // JALR vs Branch/JAL
    assign pc_src    = jump | branch_taken;
    assign pc_next   = pc_src ? pc_target : pc_plus4;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) pc <= 32'h0;
        else        pc <= pc_next;
    end

    // Submodules
    regfile u_regfile (
        .clk       (clk),
        .reg_write (reg_write),
        .rs1_addr  (rs1),
        .rs2_addr  (rs2),
        .rd_addr   (rd),
        .wdata     (result_data),
        .rs1_data  (rs1_data),
        .rs2_data  (rs2_data)
    );

    imm_gen u_imm_gen (
        .inst (inst),
        .imm  (imm)
    );

    assign alu_src_a_data = alu_src_a ? pc  : rs1_data;
    assign alu_src_b_data = alu_src_b ? imm : rs2_data;

    alu u_alu (
        .a        (alu_src_a_data),
        .b        (alu_src_b_data),
        .alu_op   (alu_op),
        .result   (alu_result),
        .zero     ()
    );

    multiplier u_multiplier (
        .a      (rs1_data),
        .b      (rs2_data),
        .funct3 (funct3),
        .result (mul_result)
    );

    branch_unit u_branch_unit (
        .rs1_data     (rs1_data),
        .rs2_data     (rs2_data),
        .funct3       (funct3),
        .branch_en    (branch_en),
        .branch_taken (branch_taken)
    );

    // Memory & Writeback
    assign mem_addr  = alu_result;

    logic [1:0] byte_offset;
    assign byte_offset = mem_addr[1:0];

    logic [7:0]  rs2_b;
    logic [15:0] rs2_h;
    assign rs2_b = rs2_data[7:0];
    assign rs2_h = rs2_data[15:0];

    always_comb begin
        case (funct3)
            FUNCT3_SB: begin
                case (byte_offset)
                    2'b00: begin mem_wdata = {24'b0, rs2_b};        mem_wstrb = 4'b0001; end
                    2'b01: begin mem_wdata = {16'b0, rs2_b, 8'b0};  mem_wstrb = 4'b0010; end
                    2'b10: begin mem_wdata = {8'b0,  rs2_b, 16'b0}; mem_wstrb = 4'b0100; end
                    2'b11: begin mem_wdata = {rs2_b, 24'b0};        mem_wstrb = 4'b1000; end
                endcase
            end
            FUNCT3_SH: begin
                if (byte_offset[1]) begin
                    mem_wdata = {rs2_h, 16'b0};
                    mem_wstrb = 4'b1100;
                end else begin
                    mem_wdata = {16'b0, rs2_h};
                    mem_wstrb = 4'b0011;
                end
            end
            FUNCT3_SW: begin
                mem_wdata = rs2_data;
                mem_wstrb = 4'b1111;
            end
            default: begin
                mem_wdata = rs2_data;
                mem_wstrb = 4'b1111;
            end
        endcase
    end

    logic [7:0] rdata_b0, rdata_b1, rdata_b2, rdata_b3;
    assign rdata_b0 = mem_rdata[7:0];
    assign rdata_b1 = mem_rdata[15:8];
    assign rdata_b2 = mem_rdata[23:16];
    assign rdata_b3 = mem_rdata[31:24];

    logic [15:0] rdata_h0, rdata_h1;
    assign rdata_h0 = mem_rdata[15:0];
    assign rdata_h1 = mem_rdata[31:16];

    logic [7:0]  selected_byte;
    logic [15:0] selected_half;

    always_comb begin
        case (byte_offset)
            2'b00:   selected_byte = rdata_b0;
            2'b01:   selected_byte = rdata_b1;
            2'b10:   selected_byte = rdata_b2;
            2'b11:   selected_byte = rdata_b3;
        endcase
    end

    assign selected_half = mem_addr[1] ? rdata_h1 : rdata_h0;

    logic byte_sign;
    logic half_sign;
    assign byte_sign = selected_byte[7];
    assign half_sign = selected_half[15];

    logic [31:0] load_data;

    always_comb begin
        case (funct3)
            FUNCT3_LB:  load_data = {{24{byte_sign}}, selected_byte};
            FUNCT3_LH:  load_data = {{16{half_sign}}, selected_half};
            FUNCT3_LW:  load_data = mem_rdata;
            FUNCT3_LBU: load_data = {24'b0, selected_byte};
            FUNCT3_LHU: load_data = {16'b0, selected_half};
            default:    load_data = mem_rdata;
        endcase
    end

    always_comb begin
        case (result_src)
            RESULT_ALU: result_data = alu_result;
            RESULT_MEM: result_data = load_data;
            RESULT_PC4: result_data = pc_plus4;
            RESULT_IMM: result_data = imm;
            RESULT_MDU: result_data = mul_result;
            default:    result_data = alu_result;
        endcase
    end

endmodule

