module tickGen #(
    parameter CLK_FREQ  = 100_000_000,
    parameter TICK_FREQ = 10_000
)(
    input clk, rst,

    output reg tick
);

    localparam TICK_PERIOD = CLK_FREQ / TICK_FREQ;  // = 10_000
    localparam CNT_WIDTH = $clog2(TICK_PERIOD);

    reg [CNT_WIDTH-1:0] cnt;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cnt  <= 0;
            tick <= 0;
        end
        
        else begin
            if (cnt == TICK_PERIOD - 1) begin
                cnt  <= 0;
                tick <= 1'b1;
            end
            else begin
                cnt  <= cnt + 1;
                tick <= 1'b0;
            end
        end
    end

endmodule
