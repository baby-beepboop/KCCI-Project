module txCore #(
    parameter BPS = 9600
)(
    input clk, rst,

    input       en,
    input [7:0] data,

    output reg busy, done,
    output reg txOut
    );

    localparam CLKS_PER_BIT = 100_000_000 / BPS;    // = 10416
    reg [$clog2(CLKS_PER_BIT)-1:0] baudCnt;
    reg baudTick;

    reg [2:0] dataBitIdx;

    reg [7:0] dataReg;

    localparam IDLE=0, START=1, DATA=2, STOP=3;
    reg [1:0] cState, nState;

    // Baud rate tick
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            baudCnt <= 0;
            baudTick <= 0;
        end

        else begin
            if (baudCnt == CLKS_PER_BIT - 1) begin
                baudCnt <= 0;
                baudTick <= 1'b1;
            end
            else begin
                baudCnt <= baudCnt + 1;
                baudTick <= 1'b0;
            end
        end
    end

    // 송신 데이터(data) 비트 인덱스 카운터
    always @(posedge clk, posedge rst) begin
        if (rst) dataBitIdx <= 0;
        else if ((cState == IDLE) && en) dataBitIdx <= 0;

        else if ((cState == DATA) && baudTick) begin
            dataBitIdx <= dataBitIdx + 1;
        end
    end

    // FSM 상태 전이
    always @(posedge clk or posedge rst) begin
        if (rst) cState <= IDLE;
        else     cState <= nState;
    end

    always @(*) begin
        nState = cState;

        case (cState)
            IDLE:  if (en)                            nState = START;
            START: if (baudTick)                      nState = DATA;
            DATA:  if (baudTick && (dataBitIdx == 7)) nState = STOP;
            STOP:  if (baudTick)                      nState = IDLE;
            default: nState = IDLE;
        endcase
    end

    // 출력 신호
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            busy <= 0;
            done <= 0;
            dataReg <= 0;
            txOut <= 1;
        end

        else begin
            case (cState)
                IDLE: begin
                    done <= 1'b0;
                    if (en) begin
                        dataReg <= data;
                        busy <= 1'b1;
                    end
                end
                START: begin
                    if (baudTick) begin
                        txOut <= 1'b0;    // Start bit
                    end
                end
                DATA: begin
                    if (baudTick) begin
                        txOut <= dataReg[dataBitIdx];
                    end
                end
                STOP: begin
                    if (baudTick) begin
                        txOut <= 1'b1;    // Stop bit
                        busy <= 1'b0;
                        done <= 1'b1;
                    end
                end
            endcase
        end
    end

endmodule
