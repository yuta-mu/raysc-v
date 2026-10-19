module uart_tx_fifo #(
    parameter int CLK_FREQ   = 50_000_000,
    parameter int BAUD_RATE  = 115_200,
    parameter int FIFO_DEPTH = 512
)(
    input  logic       clk,
    input  logic       rst_n,

    input  logic       uart_write,
    input  logic [7:0] uart_wdata,
    output logic       uart_stall,

    output logic       uart_tx
);
    
    localparam int ADDR_W = $clog2(FIFO_DEPTH); // 9bit

    (* ram_style = "distributed" *)
    logic [7:0] fifo_mem [0:FIFO_DEPTH-1];

    logic [ADDR_W:0]   wptr;
    logic [ADDR_W:0]   rptr;
    logic [ADDR_W-1:0] waddr;
    logic [ADDR_W-1:0] raddr;
    logic              fifo_empty;
    logic              fifo_full;
    logic [7:0]        fifo_rdata;
    logic              fifo_pop;

    assign waddr      = wptr[ADDR_W-1:0];
    assign raddr      = rptr[ADDR_W-1:0];
    assign fifo_empty = (wptr == rptr);
    assign fifo_full  = (waddr == raddr) && (wptr[ADDR_W] != rptr[ADDR_W]);
    assign fifo_rdata = fifo_mem[raddr];

    assign uart_stall = uart_write && fifo_full;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wptr <= '0;
        end else if (uart_write && !fifo_full) begin
            fifo_mem[waddr] <= uart_wdata;
            wptr            <= wptr + 1'b1;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rptr <= '0;
        end else if (fifo_pop) begin
            rptr <= rptr + 1'b1;
        end
    end

    localparam int CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    logic [15:0] baud_cnt;
    logic        baud_tick;
    logic        tx_active;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            baud_cnt  <= '0;
            baud_tick <= 1'b0;
        end else if (tx_active) begin
            if (baud_cnt == CLKS_PER_BIT - 1) begin
                baud_cnt  <= '0;
                baud_tick <= 1'b1;
            end else begin
                baud_cnt  <= baud_cnt + 1'b1;
                baud_tick <= 1'b0;
            end
        end else begin
            baud_cnt  <= '0;
            baud_tick <= 1'b0;
        end
    end

    typedef enum logic [1:0] {
        ST_IDLE,
        ST_START,
        ST_DATA,
        ST_STOP
    } tx_state_t;

    tx_state_t  state;
    logic [2:0] bit_idx;
    logic [7:0] tx_shifter;
    logic       tx_out;

    assign uart_tx   = tx_out;
    assign tx_active = (state != ST_IDLE);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= ST_IDLE;
            bit_idx    <= '0;
            tx_shifter <= '0;
            tx_out     <= 1'b1;
            fifo_pop   <= 1'b0;
        end else begin
            fifo_pop <= 1'b0;

            case (state)
                ST_IDLE: begin
                    tx_out <= 1'b1;
                    if (!fifo_empty) begin
                        tx_shifter <= fifo_rdata;
                        fifo_pop   <= 1'b1;
                        state      <= ST_START;
                    end
                end

                ST_START: begin
                    tx_out <= 1'b0; // スタートビット (Low)
                    if (baud_tick) begin
                        bit_idx <= '0;
                        state   <= ST_DATA;
                    end
                end

                ST_DATA: begin
                    tx_out <= tx_shifter[bit_idx];
                    if (baud_tick) begin
                        if (bit_idx == 3'd7) begin
                            state <= ST_STOP;
                        end else begin
                            bit_idx <= bit_idx + 1'b1;
                        end
                    end
                end

                ST_STOP: begin
                    tx_out <= 1'b1; // ストップビット (High)
                    if (baud_tick) begin
                        state <= ST_IDLE;
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
