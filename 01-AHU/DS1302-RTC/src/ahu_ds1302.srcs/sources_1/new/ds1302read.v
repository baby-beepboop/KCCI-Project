// ds1302read v2.0.0: 시프트 로직 수정, FSM 단순화
//            v2.0.1: readSeq 인덱스 오류 수정
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

    reg [2:0] bitCnt;    // 전송/수신된 비트 카운터 (0-7)
    reg [7:0] shiftReg;

    localparam [3:0] IDLE=0, START=1, SEND_CMD=2, TURN_IO=3, RECEIVE_DATA=4, STOP=5;
    reg [3:0] cState, nState;

    localparam [7:0] SEC_ADDR = 8'h81, MIN_ADDR = 8'h83, HRS_ADDR = 8'h85,
                     DATE_ADDR = 8'h87, MON_ADDR = 8'h89, DAY_ADDR = 8'h8B, YR_ADDR = 8'h8D;
    reg [2:0] readSeq;    // 읽은 레지스터 순서 (0-6)
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
            IDLE:         if (en)                           nState = START;
            START:                                          nState = SEND_CMD;
            SEND_CMD:     if (sclkFalling && (bitCnt == 7)) nState = TURN_IO;
            TURN_IO:      if (sclkFalling)                  nState = RECEIVE_DATA;
            RECEIVE_DATA: if (sclkFalling && (bitCnt == 7)) nState = STOP;
            STOP:                                           nState = (readSeq == 6) ? IDLE : START;
            default: nState = IDLE;
        endcase
    end

    // FSM 동작
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ce <= 0; ioDir <= 0;
            bitCnt <= 0; shiftReg <= 0;
            dataOut <= 0; done <= 0;
            readSeq <= 0; nAddr <= SEC_ADDR;
            secData <= 0; minData <= 0; hrsData <= 0; dateData <= 0; monData <= 0; dayData <= 0; yrData <= 0;
        end

        else begin
            done <= 1'b0;

            case (cState)
                IDLE: begin
                    ce <= 1'b0;
                    ioDir <= 1'b0;
                    if (en) begin
                        readSeq <= 0;
                        nAddr <= SEC_ADDR;
                        $display("[%0t] [DUT] Read Started for Addr %h", $time, SEC_ADDR);
                    end
                end

                // Protocol: CE High
                START: begin
                    ce <= 1'b1;
                    ioDir <= 1'b1;
                    shiftReg <= nAddr;
                    bitCnt <= 0;
                    dataOut <= nAddr[0];
                    $display("[%0t] [DUT] CE High. Start sending Addr %h. ioDir=1 (Output)", $time, nAddr);
                end

                // Protocol: Command Write (LSB first)
                SEND_CMD: begin
                    if (sclkFalling) begin
                        shiftReg <= shiftReg >> 1;

                        if (bitCnt == 7) begin
                            bitCnt <= 0;
                            $display("[%0t] [DUT] Address Sent Complete (Addr: %h)", $time, nAddr);
                        end
                        else begin
                            bitCnt <= bitCnt + 1;
                            dataOut <= shiftReg[1];
                        end
                    end
                end

                TURN_IO: begin
                    shiftReg <= 0;
                end

                // Protocol: Data Read (LSB first)
                RECEIVE_DATA: begin
                    ioDir <= 0;

                    if (sclkRising) begin
                        shiftReg[bitCnt] <= dataIn;
                        if (bitCnt == 7) begin
                            bitCnt <= 0;
                            $display("[%0t] [DUT] BYTE RECIEVE DONE. Value=%h", $time, shiftReg);
                        end
                        else begin
                            bitCnt <= bitCnt + 1;
                        end
                    end
                end

                // Protocol: CE Low
                STOP: begin
                    case (readSeq)
                        3'd0: secData <= shiftReg;
                        3'd1: minData <= shiftReg;
                        3'd2: hrsData <= shiftReg;
                        3'd3: dateData <= shiftReg;
                        3'd4: monData <= shiftReg;
                        3'd5: dayData <= shiftReg;
                        3'd6: yrData <= shiftReg;
                    endcase
                    $display("[%0t] [DUT] Data Received: Addr=%h, Value=%h (readSeq=%d)", $time, nAddr, shiftReg, readSeq);

                    if (readSeq != 3'd6) begin
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
                    else begin
                        ce <= 1'b0;
                        done <= 1'b1;
                        $display("[%0t] [DUT] All Read Cycles Complete.", $time);
                    end
                end
            endcase
        end
    end

endmodule
