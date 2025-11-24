module tickGen #(
    parameter CLK_FREQ  = 100_000_000,    // 입력 clock 주파수
    parameter TICK_FREQ = 1000            // 출력 tick 주파수
)(
    input clk100Mhz, rst,

    output reg tick
    );

    localparam TICK_CNT = CLK_FREQ / TICK_FREQ;               // 100_000_000 / 1000 = 100_000
    localparam TICK_WIDTH = $clog2(TICK_CNT);                 // = 16
    localparam [TICK_WIDTH-1:0] TICK_MAX = TICK_CNT - 1;

    reg [TICK_WIDTH-1:0] cnt;

    always @(posedge clk100Mhz, posedge rst) begin
        if (rst) begin
            cnt <= 0;
            tick <= 0;
        end

        else begin
            if (cnt == TICK_MAX) begin
                cnt <= 0;
                tick <= 1'b1;             // 1 clock pulse
            end
            else begin
                    cnt <= cnt + 1'b1;
                    tick <= 1'b0;
            end
        end
    end

endmodule
