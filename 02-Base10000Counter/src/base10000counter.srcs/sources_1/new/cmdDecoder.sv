// 명령어 디코더 v2.0.0: 출력 메시지의 첫 글자에 이전 명령어의 첫 글자가 출력되는 버그 수정
module cmdDecoder(
    input clk, rst,

    input      [7:0] cmd,
    output reg       runStopCmd, clearCmd, modeCmd,

    input            txBusy, txDone,
    output reg       txEn,
    output reg [7:0] msg
    );

    logic msgSet;
    logic sending;

    localparam MSG_LEN = 10;
    logic [7:0] msgBuff [0:MSG_LEN-1];
    logic [MSG_LEN-1:0] idx;

    // 명령어 파싱 & 출력 메시지 버퍼 업데이트
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            runStopCmd <= 0;
            clearCmd <= 0;
            modeCmd <= 0;
            msgSet <= 0;
            for (int i=0; i<MSG_LEN; i++) msgBuff[i] <= 0;
        end
        else begin
            runStopCmd <= 1'b0;
            clearCmd <= 1'b0;
            modeCmd <= 1'b0;
            msgSet <= 1'b0;

            case (cmd)
                "R": begin    // R: Run/Stop
                    runStopCmd <= 1'b1;
                    msgSet <= 1'b1;

                    msgBuff[0] = "R"; msgBuff[1] = "u"; msgBuff[2] = "n"; msgBuff[3] = "/";
                    msgBuff[4] = "S"; msgBuff[5] = "t"; msgBuff[6] = "o"; msgBuff[7] = "p";
                    msgBuff[8] = 8'h0D; msgBuff[9] = 8'h0A;    // CR, LF
                end
                "C": begin    // C: Clear
                    clearCmd <= 1'b1;
                    msgSet <= 1'b1;

                    msgBuff[0] = "C"; msgBuff[1] = "l"; msgBuff[2] = "e"; msgBuff[3] = "a"; msgBuff[4] = "r";
                    msgBuff[5] = 8'h0D; msgBuff[6] = 8'h0A; msgBuff[7] = 0; msgBuff[8] = 0; msgBuff[9] = 0;
                end
                "M": begin    // M: Mode
                    modeCmd <= 1'b1;
                    msgSet <= 1'b1;

                    msgBuff[0] = "M"; msgBuff[1] = "o"; msgBuff[2] = "d"; msgBuff[3] = "e";
                    msgBuff[4] = 8'h0D; msgBuff[5] = 8'h0A; msgBuff[6] = 0; msgBuff[7] = 0; msgBuff[8] = 0; msgBuff[9] = 0;
                end
            endcase
        end
    end

    // 출력 메시지
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            txEn <= 0;
            sending <= 0;
            idx <= 0;
            msg <= 0;
        end
        else begin
            txEn <= 1'b0;

            if (msgSet && (!txBusy) && (!sending)) begin
                txEn <= 1'b1;
                sending <= 1'b1;
                idx <= 0;
                msg <= msgBuff[0];
            end
            else if (sending && txDone) begin
                if (idx == (MSG_LEN - 1)) begin
                    sending <= 1'b0;
                end
                else begin
                    txEn <= 1'b1;
                    msg <= msgBuff[idx+1];
                    idx <= idx + 1;
                end
            end
        end
    end

endmodule
