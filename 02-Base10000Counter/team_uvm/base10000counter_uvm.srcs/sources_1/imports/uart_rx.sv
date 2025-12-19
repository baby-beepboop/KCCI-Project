module uart_rx #(
    parameter BPS = 9600
)(
    input clk, rst,

    input       baudTick,
    input [3:0] baudTickCnt,

    input dataIn,

    output reg       done,
    output reg [7:0] dataOut
    );

    typedef enum logic [1:0] {IDLE, START, DATA, STOP} state_t;
    state_t cState, nState;

    logic [7:0] dataReg;
    logic [2:0] dataBitIdx;

    // FSM 상태 전환
    always_ff @(posedge clk or posedge rst) begin
        if (rst) cState <= IDLE;
        else cState <= nState;
    end

    always_comb begin
        nState = cState;

        case (cState)
            IDLE:  if (!dataIn)                                              nState = START;
            START: if (baudTick && (baudTickCnt == 15))                      nState = DATA;
            DATA:  if (baudTick && (baudTickCnt == 15) && (dataBitIdx == 7)) nState = STOP;
            STOP:  if (baudTick && (baudTickCnt == 15))                      nState = IDLE;
        endcase
    end

    // 출력
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            done <= 0;
            dataReg <= 0; dataBitIdx <= 0;
            dataOut <= 0;
        end

        else begin
            case (cState)
                IDLE: begin
                    done <= 1'b0;
                end
                DATA: begin
                    if (baudTick && (baudTickCnt == 7)) begin
                        dataReg[dataBitIdx] <= dataIn;
                    end
                    else if (baudTick && (baudTickCnt == 15)) begin
                        dataBitIdx <= dataBitIdx + 1;
                    end
                end
                STOP: begin
                    dataBitIdx <= 0;
                    
                    if (baudTick && (baudTickCnt == 7)) begin
                        dataOut <= dataReg;
                        done <= 1'b1;
                    end
                    else begin
                        done <= 1'b0;
                    end
                end
            endcase
        end
    end

endmodule
