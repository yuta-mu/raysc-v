`include "rv32i_types.svh"

module bram #(
    parameter int MEM_WORDS = 65536,
    parameter string INIT_FILE = "boot.hex"
)(
    input  logic        clk,
    // Port A: IF
    input  logic [31:0] a_addr,
    output logic [31:0] a_rdata,
    // Port B: MEM
    input  logic        b_en,
    input  logic        b_we,
    input  logic [3:0]  b_wstrb,
    input  logic [31:0] b_addr,
    input  logic [31:0] b_wdata,
    output logic [31:0] b_rdata
);

    localparam int ADDR_WIDTH = $clog2(MEM_WORDS);

    (* ram_style = "block" *)
    logic [31:0] mem [0:MEM_WORDS-1];

    initial begin
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);
        end
    end

    logic [ADDR_WIDTH-1:0] a_word_addr;
    logic [ADDR_WIDTH-1:0] b_word_addr;

    assign a_word_addr = a_addr[ADDR_WIDTH+1:2];
    assign b_word_addr = b_addr[ADDR_WIDTH+1:2];

    always_ff @(posedge clk) begin
        a_rdata <= mem[a_word_addr];
    end

    always_ff @(posedge clk) begin
        if (b_en) begin
            if (b_we) begin
                if (b_wstrb[0]) mem[b_word_addr][7:0]   <= b_wdata[7:0];
                if (b_wstrb[1]) mem[b_word_addr][15:8]  <= b_wdata[15:8];
                if (b_wstrb[2]) mem[b_word_addr][23:16] <= b_wdata[23:16];
                if (b_wstrb[3]) mem[b_word_addr][31:24] <= b_wdata[31:24];
            end
            b_rdata <= mem[b_word_addr];
        end
    end
endmodule
