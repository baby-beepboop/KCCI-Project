// ds1302core v1.0.0: DS1302 1바이트 Read/Write 공통 코어
// en High -> CMD 1바이트 전송 -> (Read/Write 수행) -> done High
module ds1302core(
    input clk, rst,

    input sclk,
    input dataIn,
    
    input       en,
    input       rw,               // 0: Write, 1: Read
    input [7:0] cmd,              // DS1302 명령어
    input [7:0] writeData,        // Write 시 전송할 데이터 바이트

    output reg ce,
    output reg ioDir,             // 0: 입력, 1: 출력
    output reg dataOut,           // DUT -> DS1302

    output reg [7:0] readData,    // Read 결과
    output reg       done
    );

    // SCLK 엣지 감지
    reg sclkDetect;
    always @(posedge clk) sclkDetect <= sclk;

    wire sclkRise = sclk && (~sclkDetect);
    wire sclkFall = (~sclk) && (sclkDetect);

    localparam [3:0] IDLE=0, CMD_SHIFT=1, TURN_IO=2, READ=3, WRITE=4, FINISH=5;
    reg [3:0] cState, nState;

    reg [2:0] bitCnt;
    reg [7:0] shiftReg;

    // FSM 상태 전이
    always @(posedge clk or posedge rst) begin
        if (rst) cState <= IDLE;
        else cState <= nState;
    end

    always @(*) begin
        nState = cState;

        case (cState)
            IDLE:      if (en)                        nState = CMD_SHIFT;
            CMD_SHIFT: if (sclkFall && (bitCnt == 7)) nState = (rw) ? TURN_IO : WRITE;
            TURN_IO:   if (sclkFall)                  nState = READ;
            READ:      if (sclkRise && (bitCnt == 7)) nState = FINISH;
            WRITE:     if (sclkFall && (bitCnt == 7)) nState = FINISH;
            FINISH:                                   nState = IDLE;
            default: nState = IDLE;
        endcase
    end

    // FSM 동작
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ce <= 0; ioDir <= 0;
            dataOut <= 0; bitCnt <= 0; shiftReg <= 0;
            readData <= 0;
            done <= 0;
        end

        else begin
            done <= 1'b0;

            case (cState)
                IDLE: begin
                    ce <= 1'b0;
                    ioDir <= 1'b0;
                    bitCnt <= 0;

                    if (en) begin
                        ce <= 1'b1;
                        ioDir <= 1'b1;
                        shiftReg <= cmd;
                        dataOut <= cmd[0];
                    end
                end

                CMD_SHIFT: begin
                    ioDir <= 1'b1;

                    if (sclkFall) begin
                        shiftReg <= {1'b0, shiftReg[7:1]};
                        dataOut <= shiftReg[1];
                        bitCnt <= bitCnt + 1;
                    end
                end

                TURN_IO: begin
                    ioDir <= 1'b0;
                    bitCnt <= 0;
                end

                READ: begin
                    ioDir <= 1'b0;

                    if (sclkRise) begin
                        readData[bitCnt] <= dataIn;
                        bitCnt <= bitCnt + 1;
                    end
                end

                WRITE: begin
                    ioDir <= 1'b1;
                    dataOut <= shiftReg[0];

                    if (sclkFall) begin
                        shiftReg <= {1'b0, shiftReg[7:1]};
                        bitCnt <= bitCnt + 1;
                    end
                end

                FINISH: begin
                    ce <= 1'b0;
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule
