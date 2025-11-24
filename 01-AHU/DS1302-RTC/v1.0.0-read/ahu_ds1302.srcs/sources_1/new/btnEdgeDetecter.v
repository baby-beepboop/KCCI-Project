// btnEdgeDetecter v1.0.0: 버튼 입력의 노이즈 제거 및 누르는 순간 1회 펄스 발생시키기
module btnEdgeDetecter(
    input clk, rst,
    input tick,

    input btnRaw,
    output reg btnPulse
    );

    // 디바운싱 (노이즈 제거)
    localparam CNT_MAX = 10;    // 안정에 필요한 연속 tick 수 (10ms)
    reg [3:0] cnt;
    reg btnDb;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            cnt <= 0;
            btnDb <= 0;
        end

        else if (tick) begin
            if (btnRaw == btnDb) begin
                cnt <= 0;
            end

            else begin
                cnt <= cnt + 1;

                if (cnt >= CNT_MAX-1) begin    // 10ms가 지나면 debouncing
                    btnDb <= btnRaw;
                    cnt <= 0;
                end
            end
        end
    end

    // 상승 엣지 검출
    reg btnPrev;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            btnPrev <= 0;
            btnPulse <= 0;
        end
        
        else begin
            btnPrev <= btnDb;
            btnPulse <= btnDb & (~btnPrev);
        end
    end

endmodule
