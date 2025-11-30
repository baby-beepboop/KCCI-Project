// ds1302write v1.0.0: DS1302 RTC 칩에 1바이트 데이터 쓰기
//             v2.0.0: FSM 동작 중복 로직 제거 및 수정
// Protocol: CE High -> Command Write -> Data Write -> CE Low
module ds1302write(
    // 시스템 인터페이스
    input clk, rst,

    input       en,              // 쓰기 요청 신호
    input [7:0] addr,            // 쓰기 할 주소
    input [7:0] dataIn,          // 쓸 데이터

    // DS1302 3-wire 인터페이스
    input      sclk,             // DS1302 Serial Clock
    output reg ce,               // DS1302 Chip Enable

    output reg ioDir,            // 1: 출력 모드, 0: 대기
    output reg dataOut,          // DS1302 Bi-directional Data Line (Output Only)

    // 출력 인터페이스
    output reg done              // 쓰기 완료 신호
    );

    reg sclkDelay;
    wire sclkRising, sclkFalling;

    localparam [3:0] IDLE=0, START=1, SEND_CMD=2, SEND_DATA=3, STOP=4;
    reg [3:0] cState, nState;

    reg [3:0] bitCnt;
    reg [7:0] shiftReg;

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
            IDLE:      if (en)                           nState = START;
            START:                                       nState = SEND_CMD;
            SEND_CMD:  if (sclkFalling && (bitCnt == 7)) nState = SEND_DATA;
            SEND_DATA: if (sclkFalling && (bitCnt == 7)) nState = STOP;
            STOP:                                        nState = IDLE;
            default: nState = IDLE;
        endcase
    end

    // FSM 동작
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ce <= 0; ioDir <= 0;
            bitCnt <= 0; shiftReg <= 0;
            dataOut <= 0; done <= 0;
        end

        else begin
            done <= 1'b0;

            if (sclkFalling) begin
                if ((cState == SEND_CMD) || (cState == SEND_DATA)) begin
                    shiftReg <= shiftReg >> 1;

                    if (bitCnt < 7) begin
                        dataOut <= shiftReg[1];
                    end
                    else if (cState == SEND_CMD) begin
                        dataOut <= dataIn[0];
                    end
                end
            end

            case (cState)
                IDLE: begin
                    ce <= 1'b0;
                    ioDir <= 1'b0;
                    bitCnt <= 0;
                end

                // Protocol: CE High
                START: begin
                    ce <= 1'b1;
                    ioDir <= 1'b1;
                    shiftReg <= addr;
                    dataOut <= addr[0];
                    bitCnt <= 0;
                end

                // Protocol: Command Write (LSB first)
                SEND_CMD: begin
                    if (sclkFalling) begin
                        if (bitCnt == 7) begin
                            bitCnt <= 0;
                            shiftReg <= dataIn;
                            dataOut <= dataIn[0];
                        end
                        else begin
                            bitCnt <= bitCnt + 1;
                            shiftReg <= shiftReg >> 1;
                            dataOut <= shiftReg[1];
                        end
                    end
                end

                SEND_DATA: begin
                    if (sclkFalling) begin
                        // Protocol: CE Low
                        if (bitCnt == 7) begin
                            bitCnt <= 0;
                            ce <= 1'b0;
                            ioDir <= 1'b0;
                            done <= 1'b1;
                            dataOut <= 0;
                        end

                        // Protocol: Data Write (LSB first)
                        else begin
                            bitCnt <= bitCnt + 1;
                            shiftReg <= shiftReg >> 1;
                            dataOut <= shiftReg[1];
                        end
                    end
                end

                STOP: begin
                    ce <= 0;
                    ioDir <= 0;
                    done <= 0;
                end
            endcase
        end
    end

endmodule
