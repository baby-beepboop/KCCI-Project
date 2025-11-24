// rtcCtrl v1.1.0: 로터리 엔코더 입력으로 FND 값 증감
module rtcCtrl(
    input clk, rst,

    input       btn,
    input [5:0] mode,                                                    // 0: Display Mode, 1-5: Write Mode
    input       cw, ccw, save,

    input [7:0] minData, hrsData, dateData, monData, dayData, yrData,

    output reg [3:0] fndD0, fndD1, fndD2, fndD3,
    output reg [1:0] fndDot                                              // [1]: D2의 dot, [0]: D0의 dot
    );

    localparam [1:0] TIME=0, DATE=1, DAY=2, YEAR=3;
    reg [1:0] dispState;

    reg [2:0] editMode;
    reg editing;

    reg [7:0] baseVal, editValReg, viewVal;

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

    // Write Mode 디코더
    always @(*) begin
        if (mode[1])      editMode = 1;    // 연도
        else if (mode[2]) editMode = 2;    // 달
        else if (mode[3]) editMode = 3;    // 일
        else if (mode[4]) editMode = 4;    // 시
        else if (mode[5]) editMode = 5;    // 분
        else              editMode = 0;
    end

    // Decimal to BCD
    function [7:0] bcdInc;
        input [7:0] val, maxVal;

        reg [7:0] dec;
        reg [3:0] t, u;
        begin
            dec = (val[7:4]*10) + val[3:0];
            if (((dec == 0) && (maxVal != 0)) && (val == maxVal)) begin
                dec = ((maxVal == 8'h12) || (maxVal == 8'h31)) ? 1 : 0;
            end
            else if (dec >= ((maxVal[7:4]*10) + maxVal[3:0])) begin
                dec = ((maxVal == 8'h12) || (maxVal == 8'h31)) ? 1 : 0;
            end
            else begin
                dec = dec + 1;
            end

            t = dec / 10;
            u = dec % 10;
            bcdInc = {t, u};
        end
    endfunction

    function [7:0] bcdDec;
        input [7:0] val, maxVal, minVal;

        reg [7:0] dec;
        reg [3:0] t, u;
        begin
            dec = (val[7:4]*10) + val[3:0];
            if (dec <= ((minVal[7:4]*10) + minVal[3:0])) begin
                dec = (maxVal[7:4]*10) + minVal[3:0];
            end
            else begin
                dec = dec - 1;
            end

            t = dec / 10;
            u = dec % 10;
            bcdDec = {t, u};
        end
    endfunction

    // Write Mode FSM
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            editing <= 0;
            baseVal <= 0;
            editValReg <= 0;
        end
        else begin
            // 값 편집
            if (editMode != 0) begin
                case (editMode)
                    1: baseVal <= (editing) ? editValReg : yrData;
                    2: baseVal <= (editing) ? editValReg : monData;
                    3: baseVal <= (editing) ? editValReg : dateData;
                    4: baseVal <= (editing) ? editValReg : hrsData;
                    5: baseVal <= (editing) ? editValReg : minData;
                    default: baseVal <= 0;
                endcase

                // 로터리 입력 처리
                if (cw) begin
                    case (editMode)
                        1: editValReg <= bcdInc(baseVal, 8'h99);
                        2: editValReg <= bcdInc(baseVal, 8'h12);
                        3: editValReg <= bcdInc(baseVal, 8'h31);
                        4: editValReg <= bcdInc(baseVal, 8'h23);
                        5: editValReg <= bcdInc(baseVal, 8'h59);
                    endcase
                    editing <= 1'b1;
                end
                else if (ccw) begin
                    case (editMode)
                        1: editValReg <= bcdDec(baseVal, 8'h99, 8'h00);
                        2: editValReg <= bcdDec(baseVal, 8'h12, 8'h01);
                        3: editValReg <= bcdDec(baseVal, 8'h31, 8'h01);
                        4: editValReg <= bcdDec(baseVal, 8'h23, 8'h00);
                        5: editValReg <= bcdDec(baseVal, 8'h59, 8'h00);
                    endcase
                    editing <= 1'b1;
                end
            end
            else begin
                editing <= 1'b0;
            end
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

        // Write Mode
        else if (editMode != 0) begin
            case (editMode)
                1: viewVal = (editing) ? editValReg : yrData;
                2: viewVal = (editing) ? editValReg : monData;
                3: viewVal = (editing) ? editValReg : dateData;
                4: viewVal = (editing) ? editValReg : hrsData;
                5: viewVal = (editing) ? editValReg : minData;
                default: viewVal = 0;
            endcase

            case (editMode)
                1: begin    // 20YY.
                    fndD3 = 4'd2; fndD2 = 4'd0;
                    fndD1 = viewVal[7:4]; fndD0 = viewVal[3:0];
                    fndDot = 2'b10;
                end
                2: begin    // MM.DD.
                    fndD3 = viewVal[7:4]; fndD2 = viewVal[3:0];
                    fndD1 = dateData[7:4]; fndD0 = dateData[3:0];
                    fndDot = 2'b00;
                end
                3: begin    // MM.DD.
                    fndD3 = monData[7:4]; fndD2 = monData[3:0];
                    fndD1 = viewVal[7:4]; fndD0 = viewVal[3:0];
                    fndDot = 2'b00;
                end
                4: begin    // HH.MM
                    fndD3 = viewVal[7:4]; fndD2 = viewVal[3:0];
                    fndD1= minData[7:4]; fndD0 = minData[3:0];
                    fndDot = 2'b01;
                end
                5: begin    // HH.MM
                    fndD3 = hrsData[7:4]; fndD2 = hrsData[3:0];
                    fndD1 = viewVal[7:4]; fndD0 = viewVal[3:0];
                    fndDot = 2'b01;
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
