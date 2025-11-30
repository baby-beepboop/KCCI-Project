// ds1302read v3.0.0: 1바이트 core(ds1302core)를 이용하여 7가지 레지스터를 읽는 래퍼
module ds1302read(
    input clk, rst,

    input sclk,
    input dataIn,

    input  en,

    output ce,
    output ioDir,
    output dataOut,

    output reg [7:0] secData, minData, hrsData, dateData, monData, dayData, yrData,

    output reg done
    );

    localparam [2:0] IDLE=0, SEND=1, WAIT=2, STORE=3, NEXT=4, FINISH=5;
    reg [2:0] cState, nState;

    reg [2:0] idx;
    reg [7:0] cmd;

    wire coreDone;
    wire coreCe, coreIoDir, coreOut;
    wire [7:0] coreData;

    assign ce = coreCe;
    assign ioDir = coreIoDir;
    assign dataOut = coreOut;

    // 주소 매핑
    always @(*) begin
        case (idx)
            3'd0: cmd = 8'h81;    // Sec
            3'd1: cmd = 8'h83;    // Min
            3'd2: cmd = 8'h85;    // Hrs
            3'd3: cmd = 8'h87;    // Date
            3'd4: cmd = 8'h89;    // Mon
            3'd5: cmd = 8'h8B;    // Day
            3'd6: cmd = 8'h8D;    // Year
            default: cmd = 8'h81;
        endcase
    end

    // DS1302 Core
    ds1302core u_core (
        .clk(clk), .rst(rst),
        .sclk(sclk), .dataIn(dataIn),
        .en(cState == SEND),
        .rw(1'b1),
        .cmd(cmd),
        .writeData(8'h00),
        .ce(coreCe),
        .ioDir(coreIoDir),
        .dataOut(coreOut),
        .readData(coreData),
        .done(coreDone));

    // FSM 상태 전이
    always @(posedge clk or posedge rst) begin
        if (rst) cState <= IDLE;
        else cState <= nState;
    end

    always @(*) begin
        nState = cState;

        case (cState)
            IDLE: if (en)       nState = SEND;
            SEND:               nState = WAIT;
            WAIT: if (coreDone) nState = STORE;
            STORE:              nState = (idx == 6) ? FINISH : NEXT;
            NEXT:               nState = SEND;
            default: nState = IDLE;
        endcase
    end

    // FSM 동작
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            idx <= 0;
            done <= 0;
            secData <= 0; minData <= 0; hrsData <= 0; dateData <= 0; monData <= 0; dayData <= 0; yrData <= 0;
        end

        else begin
            done <= 1'b0;

            case (cState)
                IDLE: begin
                    if (en) begin
                        idx <= 0;
                    end
                end

                SEND: begin
                end

                WAIT: begin
                end

                STORE: begin
                    case (idx)
                        3'd0: secData <= coreData;
                        3'd1: minData <= coreData;
                        3'd2: hrsData <= coreData;
                        3'd3: dateData <= coreData;
                        3'd4: monData <= coreData;
                        3'd5: dayData <= coreData;
                        3'd6: yrData <= coreData;
                    endcase
                end

                NEXT: begin
                    idx <= idx + 1;
                end

                FINISH: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule
