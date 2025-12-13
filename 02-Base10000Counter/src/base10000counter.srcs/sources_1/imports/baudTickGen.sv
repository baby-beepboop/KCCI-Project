module baudTickGen #(
    parameter BPS = 9600
)(
    input clk, rst,

    output reg       tick,
    output reg [3:0] tickCnt
    );

    localparam CLKS_PER_BIT = 100_000_000 / (BPS * 16);    // = 651
    logic [$clog2(CLKS_PER_BIT)-1:0] clkCnt;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            clkCnt <= 0;
            tick <= 0;
            tickCnt <= 0;
        end

        else begin
            if (clkCnt == CLKS_PER_BIT - 1) begin
                clkCnt <= 0;
                tick <= 1'b1;
                tickCnt <= tickCnt + 1;
            end
            else begin
                clkCnt <= clkCnt + 1;
                tick <= 1'b0;
            end
        end
    end

endmodule
