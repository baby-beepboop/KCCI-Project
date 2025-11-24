// ds1302read v1.0.0: DS1302 RTC 칩에서 초, 분, 시, 날짜 등 7가지 레지스터 데이터를 순차적으로 읽기
// Protocol: CE High -> Command Write -> Data Read -> CE Low
module ds1302read(
    // 시스템 인터페이스
    input clk, rst,

    input en,                     // 읽기 동작 시작 트리거

    // DS1302 3-wire 인터페이스
    input      sclk,              // DS1302 Serial Clock
    output reg ce,                // DS1302 Chip Enable
    input      dataIn,            // DS1302 Bi-directional Data Line (Input Only)

    output reg ioDir,             // 0: 입력(데이터 수신), 1: 출력(주소 전송)
    output reg dataOut,

    // 출력 데이터 인터페이스
    output reg [7:0] secData, minData, hrsData, dateData, monData, dayData, yrData,
    output reg       done         // 읽기 완료 신호
    );

    reg sclkDelay;
    wire sclkRising, sclkFalling;

    reg [2:0] dataBitCnt;    // 전송/수신된 비트 카운터 (0-7)
    reg [7:0] shiftReg;

    localparam IDLE=0, START_CMD=1, SEND_ADDR_H=2, SEND_ADDR_L=3, TURN_IO=4, READ_DATA_H=5, READ_DATA_L=6, STOP_CMD=7;
    reg [3:0] cState, nState;

    localparam [7:0] SEC_ADDR = 8'h81, MIN_ADDR = 8'h83, HRS_ADDR = 8'h85,
                     DATE_ADDR = 8'h87, MON_ADDR = 8'h89, DAY_ADDR = 8'h8B, YR_ADDR = 8'h8D;
    reg [2:0] readSeq;
    reg [7:0] nAddr;

    // SCLK 엣지 검출
    always @(posedge clk) begin
        sclkDelay <= sclk;
    end
    assign sclkRising = sclk & (~sclkDelay);
    assign sclkFalling = (~sclk) & sclkDelay;

    // FSM 상태 전이
    always @(posedge clk or posedge rst) begin
        if (rst) cState <= IDLE;
        else cState <= nState;
    end

    always @(*) begin
        nState = cState;

        case (cState)
            IDLE:        if (en)         nState = START_CMD;
            START_CMD:                   nState = SEND_ADDR_H;
            SEND_ADDR_H: if (sclkRising) nState = SEND_ADDR_L;
            SEND_ADDR_L: begin
                if (sclkFalling) begin
                    if (dataBitCnt == 7) nState = TURN_IO;
                    else nState = SEND_ADDR_H;
                end
            end
            TURN_IO:                     nState = READ_DATA_H;
            READ_DATA_H: if (sclkRising) nState = READ_DATA_L;
            READ_DATA_L: begin
                if (sclkFalling) begin
                    if (dataBitCnt == 7) nState = STOP_CMD;
                    else nState = READ_DATA_H;
                end
            end
            STOP_CMD:                    nState = (readSeq == 6) ? IDLE : START_CMD;
            default: nState = IDLE;
        endcase
    end

    // FSM 동작
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ce <= 0; ioDir <= 0; done <= 0;
            readSeq <= 0; nAddr <= SEC_ADDR;
            dataBitCnt <= 0; shiftReg <= 0; dataOut <= 0;
            secData <= 0; minData <= 0; hrsData <= 0;
            dateData <= 0; monData <= 0; dayData <= 0; yrData <= 0;
        end

        else begin
            done <= 1'b0;

            case (cState)
                IDLE: begin
                    if (en) begin
                        readSeq <= 0;
                        nAddr <= SEC_ADDR;
                        shiftReg <= SEC_ADDR;
                        ioDir <= 1'b1;
                        dataBitCnt <= 0;
                        dataOut <= 0;
                    end
                end

                // Protocol: CE High
                START_CMD: begin
                    ce <= 1'b1;
                    shiftReg <= nAddr;
                    dataOut <= shiftReg[0];
                end
                
                // Protocol: Command(0x81) Write (LSB first)
                SEND_ADDR_H: begin
                    dataOut <= shiftReg[0];
                end
                SEND_ADDR_L: begin
                    dataOut <= shiftReg[0];
                    if (sclkFalling) begin
                        dataBitCnt <= dataBitCnt + 1;
                        shiftReg <= shiftReg >> 1;
                    end
                end
                TURN_IO: begin
                    ioDir <= 1'b0;
                    dataBitCnt <= 0;
                    shiftReg <= 0;
                    dataOut <= 0;
                end

                // Protocol: Data Read (LSB first)
                READ_DATA_H: begin
                    if (sclkRising) begin
                        shiftReg <= {dataIn, shiftReg[7:1]};
                    end
                end
                READ_DATA_L: begin
                    if (sclkFalling) begin
                        dataBitCnt <= dataBitCnt + 1;
                    end
                end

                // Protocol: CE Low
                STOP_CMD: begin
                    case (readSeq)
                        3'd0: secData <= shiftReg;
                        3'd1: minData <= shiftReg;
                        3'd2: hrsData <= shiftReg;
                        2'd3: dateData <= shiftReg;
                        3'd4: monData <= shiftReg;
                        3'd5: dayData <= shiftReg;
                        3'd6: yrData <= shiftReg;
                    endcase

                    ce <= 1'b0;
                    ioDir <= 0;

                    if (readSeq == 6) begin
                        done <= 1'b1;
                    end
                    else begin
                        readSeq <= readSeq + 1;
                        case (readSeq + 1)
                            3'd1: nAddr <= MIN_ADDR;
                            3'd2: nAddr <= HRS_ADDR;
                            3'd3: nAddr <= DATE_ADDR;
                            3'd4: nAddr <= MON_ADDR;
                            3'd5: nAddr <= DAY_ADDR;
                            3'd6: nAddr <= YR_ADDR;
                            default: nAddr <= 0;
                        endcase
                    end
                end
            endcase
        end
    end

endmodule
