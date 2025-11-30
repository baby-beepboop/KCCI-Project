// ds1302write v3.0.0: 1바이트 core(ds1302core)를 이용한 쓰기 래퍼
// en High -> CMD + DATA 1바이트 전송 -> Done High
module ds1302write(
    input clk, rst,

    input sclk,
    input dataIn,

    input       en,
    input [7:0] addr,
    input [7:0] dataByte,

    output ce,
    output ioDir,
    output dataOut,

    output reg done
    );

    localparam [1:0] IDLE=0, SEND=1, WAIT=2, FINISH=3;
    reg [1:0] cState, nState;

    wire coreDone;
    wire coreCe, coreIoDir, coreOut;

    assign ce = coreCe;
    assign ioDir = coreIoDir;
    assign dataOut = coreOut;

    // DS1302 Core
    ds1302core u_core (
        .clk(clk), .rst(rst),
        .sclk(sclk), .dataIn(dataIn),
        .en(cState == SEND),
        .rw(1'b0),
        .cmd(addr),
        .writeData(dataByte),
        .ce(coreCe),
        .ioDir(coreIoDir),
        .dataOut(coreOut),
        .readData(),
        .done(coreDone));

    // FSM 상태 전이
    always @(posedge clk or posedge rst) begin
        if (rst) cState <= IDLE;
        else cState <= nState;
    end
    
    always @(*) begin
        nState = cState;

        case (cState)
            IDLE:   if (en)       nState = SEND;
            SEND:                 nState = WAIT;
            WAIT:   if (coreDone) nState = FINISH;
            FINISH:               nState = IDLE;
            default: nState = IDLE;
        endcase
    end

    // FSM 동작
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            done <= 0;
        end

        else begin
            done <= 1'b0;

            case (cState)
                IDLE: begin
                end

                SEND: begin
                end

                WAIT: begin
                end

                FINISH: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule
