module top;
    reg clk;
    reg [3:0] count;

    initial begin
        clk = 0;
        count = 0;
        $dumpfile("hw/sim/wave.vcd");
        $dumpvars(0, top);
        #100 $finish;
    end

    always #5 clk = ~clk;
    always @(posedge clk) count <= count + 1;
endmodule

