// rtcCtrl v1.0.0: 슬라이드 스위치와 버튼 입력에 따라 FND 표시 데이터 결정
module rtcCtrl(
    input clk, rst,

    input       btn,
    input [5:0] mode,                                                    // 0: Display Mode, 1-5: Write Mode

    input [7:0] minData, hrsData, dateData, monData, dayData, yrData,

    output reg [3:0] fndD0, fndD1, fndD2, fndD3,
    output reg [1:0] fndDot                                              // [1]: D2의 dot, [0]: D0의 dot
    );

    localparam [1:0] TIME=0, DATE=1, DAY=2, YEAR=3;
    reg [1:0] dispState;

    // Display Mode FSM 상태 전이
    always @(posedge clk or posedge rst) begin
        if (rst) dispState <= TIME;

        else if (mode[0] && btn) begin
            case (dispState)
                TIME: dispState <= DATE;
                DATE: dispState <= DAY;
                DAY:  dispState <= YEAR;
                YEAR: dispState <= TIME;
            endcase
        end

        else if (!mode[0]) begin
            dispState <= TIME;
        end
    end

    // FND 데이터 Mux (출력)
    always @(*) begin
        fndD3 = hrsData[7:4]; fndD2 = hrsData[3:0];
        fndD1 = minData[7:4]; fndD0 = minData[3:0];
        fndDot = 2'b01;

        // Display Toggle Mode
        if (mode[0]) begin
            case (dispState)
                TIME: begin
                    fndD3 = hrsData[7:4]; fndD2 = hrsData[3:0];
                    fndD1= minData[7:4]; fndD0 = minData[3:0];
                    fndDot = 2'b01;
                end
                DATE: begin
                    fndD3 = monData[7:4]; fndD2 = monData[3:0];
                    fndD1 = dateData[7:4]; fndD0 = dateData[3:0];
                    fndDot = 2'b00;
                end
                DAY: begin
                    fndD3 = 4'hF; fndD2 = 4'hF;
                    fndD1 = 4'hF; fndD0 = dayData[3:0];    // 0: 일요일, 6: 토요일
                    fndDot = 2'b11;
                end
                YEAR: begin
                    fndD3 = 4'd2; fndD2 = 4'd0;
                    fndD1 = yrData[7:4]; fndD0 = yrData[3:0];
                    fndDot = 2'b10;
                end
            endcase
        end

        // Default
        else begin
            fndD3 = hrsData[7:4]; fndD2 = hrsData[3:0];
            fndD1= minData[7:4]; fndD0 = minData[3:0];
            fndDot = 2'b01;
        end
    end

endmodule
