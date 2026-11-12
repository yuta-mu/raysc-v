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

    localparam int ADDR_W       = $clog2(FIFO_DEPTH);
    localparam int CLKS_PER_BIT = CLK_FREQ / BAUD_RATE; // 50MHz / 115200 = 434

    (* ram_style = "distributed" *)
    logic [7:0] fifo_mem [0:FIFO_DEPTH-1];

    logic [ADDR_W:0]   wptr;
    logic [ADDR_W:0]   rptr;
    wire  [ADDR_W-1:0] waddr = wptr[ADDR_W-1:0];
    wire  [ADDR_W-1:0] raddr = rptr[ADDR_W-1:0];

    wire fifo_empty = (wptr == rptr);
    wire fifo_full  = (waddr == raddr) && (wptr[ADDR_W] != rptr[ADDR_W]);

    assign uart_stall = uart_write && fifo_full;

    // FIFO Write
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wptr <= '0;
        end else if (uart_write && !fifo_full) begin
            fifo_mem[waddr] <= uart_wdata;
            wptr            <= wptr + 1'b1;
        end
    end

    // UART TX FSM & Baud Counter
    typedef enum logic {
        ST_IDLE,
        ST_TRANSMIT
    } tx_state_t;

    tx_state_t   state;
    logic [15:0] baud_cnt;
    logic [3:0]  bit_cnt;    // 0(Start) .. 8(MSB) .. 9(Stop)
    logic [9:0]  tx_shifter; // {Stop(1'b1), Data[7:0], Start(1'b0)}
    logic        tx_out;

    assign uart_tx = tx_out;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= ST_IDLE;
            rptr       <= '0;
            baud_cnt   <= '0;
            bit_cnt    <= '0;
            tx_shifter <= 10'h3FF;
            tx_out     <= 1'b1;
        end else begin
            case (state)
                ST_IDLE: begin
                    tx_out   <= 1'b1;
                    baud_cnt <= '0; // アイドル中は必ず 0 に保持
                    bit_cnt  <= '0;
                    if (!fifo_empty) begin
                        tx_shifter <= {1'b1, fifo_mem[raddr], 1'b0};
                        rptr       <= rptr + 1'b1;
                        tx_out     <= 1'b0;
                        state      <= ST_TRANSMIT;
                    end
                end

                ST_TRANSMIT: begin
                    tx_out <= tx_shifter[0];
                    if (baud_cnt == CLKS_PER_BIT - 1) begin
                        baud_cnt <= '0;
                        if (bit_cnt == 4'd9) begin
                            if (!fifo_empty) begin
                                tx_shifter <= {1'b1, fifo_mem[raddr], 1'b0};
                                rptr       <= rptr + 1'b1;
                                tx_out     <= 1'b0;
                                bit_cnt    <= '0;
                            end else begin
                                tx_out  <= 1'b1;
                                state   <= ST_IDLE;
                                bit_cnt <= '0;
                            end
                        end else begin
                            tx_shifter <= {1'b1, tx_shifter[9:1]};
                            tx_out     <= tx_shifter[1];
                            bit_cnt    <= bit_cnt + 1'b1;
                        end
                    end else begin
                        baud_cnt <= baud_cnt + 1'b1;
                    end
                end
            endcase
        end
    end

endmodule
