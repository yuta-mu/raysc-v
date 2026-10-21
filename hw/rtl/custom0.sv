// custom0.sv : RayQ custom-0 演算器
module custom0 (
    input  logic        clk,
    input  logic        rst_n,

    input  logic        valid,
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  logic [2:0]  funct3,

    output logic [31:0] result,
    output logic        stall
);

    logic sel_sqrt, sel_rsqrt, sel_rcp;
    assign sel_sqrt  = valid && (funct3 == 3'd2);
    assign sel_rsqrt = valid && (funct3 == 3'd3);
    assign sel_rcp   = valid && (funct3 == 3'd4);

    // qmul
    logic signed [63:0] product;
    assign product = $signed(a) * $signed(b);

    // qsqrt
    logic [31:0] sqrt_result;
    logic        sqrt_done;

    qsqrt_unit #(.STEPS(4)) u_qsqrt (
        .clk    (clk),
        .rst_n  (rst_n),
        .start  (sel_sqrt),
        .a      (a),
        .result (sqrt_result),
        .busy   (),
        .done   (sqrt_done)
    );

    // qrsqrt
    logic [31:0] rsqrt_result;
    logic        rsqrt_done;

    qrsqrt_unit #(.STEPS(4)) u_qrsqrt (
        .clk    (clk),
        .rst_n  (rst_n),
        .start  (sel_rsqrt),
        .a      (a),
        .result (rsqrt_result),
        .busy   (),
        .done   (rsqrt_done)
    );

    // qrcp
    logic [31:0] rcp_result;
    logic        rcp_done;

    qrcp_unit u_qrcp (
        .clk    (clk),
        .rst_n  (rst_n),
        .start  (sel_rcp),
        .a      (a),
        .result (rcp_result),
        .busy   (),
        .done   (rcp_done)
    );

    // 結果とstall
    always_comb begin
        case (funct3)
            3'd0:    result = product[47:16]; // qmul
            3'd2:    result = sqrt_result;    // qsqrt
            3'd3:    result = rsqrt_result;   // qrsqrt
            3'd4:    result = rcp_result;     // qrcp
            default: result = 32'd0;
        endcase
    end

    assign stall = (sel_sqrt  && !sqrt_done)
                || (sel_rsqrt && !rsqrt_done)
                || (sel_rcp   && !rcp_done);

endmodule