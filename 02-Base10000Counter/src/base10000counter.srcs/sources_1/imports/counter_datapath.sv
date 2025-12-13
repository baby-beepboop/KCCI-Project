module counter_datapath(
    input clk, rst,

    input [3:0] sFlag,

    output [13:0] cnt
    );

    logic tick10k;

    tickGen #(.TICK_FREQ(10_000)) u_tick10kGen (.clk(clk), .rst(rst), .tick(tick10k));

    counter u_counter (.clk(clk), .rst(rst), .tick(tick10k), .sFlag(sFlag), .cnt(cnt));

endmodule
