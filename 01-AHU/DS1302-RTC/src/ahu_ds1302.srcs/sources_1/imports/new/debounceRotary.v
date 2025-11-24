module debounceRotary(
    input clk, rst,
    input tick,
    
    input      [2:0] btnRaw,
    output reg [2:0] btnDb
    );

    localparam CNT_MAX = 10;    // 안정에 필요한 연속 tick 수 (10ms)

    reg [3:0] cnt0, cnt1, cnt2;
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            cnt0 <= 0; cnt1 <= 0; cnt2 <= 0;
            btnDb <= 0;
        end

        else if (tick) begin
            if (btnRaw[0] == btnDb[0]) cnt0 <= 0;
            else begin
                if (cnt0 >= CNT_MAX-1) begin    // 10ms가 지나면 debouncing
                    btnDb[0] <= btnRaw[0];
                    cnt0 <= 0;
                end
                else cnt0 <= cnt0 + 1'b1;
            end

            if (btnRaw[1] == btnDb[1]) cnt1 <= 0;
            else begin
                if (cnt1 >= CNT_MAX-1) begin
                    btnDb[1] <= btnRaw[1];
                    cnt1 <= 0;
                end
                else cnt1 <= cnt1 + 1'b1;
            end

            if (btnRaw[2] == btnDb[2]) cnt2 <= 0;
            else begin
                if (cnt2 >= CNT_MAX-1) begin
                    btnDb[2] <= btnRaw[2];
                    cnt2 <= 0;
                end
                else cnt2 <= cnt2 + 1'b1;
            end
        end
    end

endmodule
