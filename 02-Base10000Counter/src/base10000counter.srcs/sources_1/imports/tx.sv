module tx #(
    parameter BPS = 9600
)(
    input clk, rst,

    input       baudTick,
    input [3:0] baudTickCnt,

    input       en,
    input [7:0] dataIn,

    output reg busy, done,
    output reg dataOut
    );

    typedef enum logic [1:0] {IDLE, START, DATA, STOP} state_t;
    state_t cState, nState;

    logic [7:0] dataReg;
    logic [2:0] dataBitIdx;

    // FSM 상태 전이
    always_ff @(posedge clk or posedge rst) begin
        if (rst) cState <= IDLE;
        else cState <= nState;
    end

    always_comb begin
        nState = cState;

        case (cState)
            IDLE:  if (en)                                                   nState = START;
            START: if (baudTick && (baudTickCnt == 15))                      nState = DATA;
            DATA:  if (baudTick && (baudTickCnt == 15) && (dataBitIdx == 7)) nState = STOP;
            STOP:  if (baudTick && (baudTickCnt == 15))                      nState = IDLE;
        endcase
    end

    // 출력
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            dataReg <= 0; dataBitIdx <= 0;
            busy <= 0; done <= 0;
            dataOut <= 1;
        end

        else begin
            case (cState)
                IDLE: begin
                    done <= 1'b0;

                    if (en) begin
                        busy <= 1'b1;
                        dataReg <= dataIn;
                    end
                end
                START: begin
                    if (baudTick && (baudTickCnt == 15)) begin
                        dataOut <= 1'b0;                          // Start bit
                    end
                end
                DATA: begin
                    if (baudTick && (baudTickCnt == 15)) begin
                        dataOut <= dataReg[dataBitIdx];
                        dataBitIdx <= dataBitIdx + 1;
                    end
                end
                STOP: begin
                    if (baudTick && (baudTickCnt == 15)) begin
                        dataBitIdx <= 0;
                        dataOut <= 1'b1;                          // Stop bit
                        busy <= 1'b0;
                        done <= 1'b1;
                    end
                end
            endcase
        end
    end

endmodule
