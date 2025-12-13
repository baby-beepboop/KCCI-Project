module counter(
    input clk, rst,
    input tick,

    input [3:0] sFlag,

    output reg [13:0] cnt
    );

    always @(posedge clk or posedge rst) begin
        if (rst) cnt <= 0;

        else begin
            casez (sFlag)
                4'b0001: cnt <= 14'd0;
                4'b0010: begin
                    if (tick) begin
                        if (cnt == 9999) cnt <= 14'd0;
                        else cnt <= cnt + 1;
                    end
                end
                4'b0100: begin
                    if (tick) begin
                        if (cnt == 0) cnt <= 14'd9999;
                        else cnt <= cnt - 1;
                    end
                end
                4'b1??0: cnt <= cnt;
            endcase
        end
    end

endmodule
