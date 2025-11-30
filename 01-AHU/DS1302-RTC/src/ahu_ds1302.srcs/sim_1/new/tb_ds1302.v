// tb_ds1302 v2.0.0: DS1302 Chip Model 수정
`timescale 1ns / 1ps

module tb_ds1302;
    reg clk, rst;

    wire sclk, ce;
    wire dsData;
    
    reg       btnR;
    reg [6:0] sw;
    reg       reA, reB, reBtn;

    wire [3:0] an;
    wire [6:0] seg;
    wire       dp;

    reg dsIoDir;
    reg dsOut;

    assign dsData = (dsIoDir) ? dsOut : 1'bz;

    initial clk = 0;
    always #5 clk = ~clk;

    // 가상 RTC 메모리 (0: Sec, 1: Min, 2: Hr, ...)
    reg [7:0] rtcMem [0:31];

    top_ds1302 dut (
        .clk(clk), .rst(rst),
        .sclk(sclk), .ce(ce), .dsData(dsData),
        .btnR(btnR), .sw(sw), .reA(reA), .reB(reB), .reBtn(reBtn),
        .an(an), .seg(seg), .dp(dp),
        .RsRx(), .RsTx());

    // SCLK 엣지 검출
    reg sclkPrev;
    always @(posedge clk) sclkPrev <= sclk;
    wire sclkRise = sclk && (~sclkPrev);
    wire sclkFall = (~sclk) && sclkPrev;

    // DS1302 Chip Model
    reg [7:0] cmdShift, dataShift;
    reg [3:0] bitCnt;
    reg       readCmd;
    reg       writing;

    localparam IDLE=0, CMD=1, READ=2, WRITE=3;
    reg [1:0] state;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            dsIoDir <= 0;
            bitCnt <= 0;
            dsOut <= 0;
            readCmd <= 0; writing <= 0;
            rtcMem[0] = 8'h00; rtcMem[1] = 8'h00; rtcMem[2] = 8'h12;
            rtcMem[3] = 8'h01; rtcMem[4] = 8'h01; rtcMem[5] = 8'h00; rtcMem[6] = 8'h00;
        end
        else if (!ce) begin    // CE Low: 통신 초기화
            state <= IDLE;
            dsIoDir <= 0;
            bitCnt <= 0;
        end

        // CE High: 통신 활성화
        else begin
            case (state)
                IDLE: begin
                    if (sclkRise) begin
                        state <= CMD;
                        bitCnt <= 0;
                    end
                end

                // CMD 수신 (LSB fist, SCLK 상승 엣지 샘플링)
                CMD: begin
                    if (sclkRise) begin
                        cmdShift[bitCnt] <= dsData;
                        bitCnt <= bitCnt + 1;

                        if (bitCnt == 7) begin
                            readCmd = cmdShift[0];
                            writing = ~readCmd;
                            bitCnt <= 0;

                            if (readCmd) begin
                                case (cmdShift[7:1])
                                    7'h40: dataShift = rtcMem[0];
                                    7'h41: dataShift = rtcMem[1];
                                    7'h42: dataShift = rtcMem[2];
                                    7'h43: dataShift = rtcMem[3];
                                    7'h44: dataShift = rtcMem[4];
                                    7'h45: dataShift = rtcMem[5];
                                    7'h46: dataShift = rtcMem[6];
                                    default: dataShift = 8'h00;
                                endcase

                                dsIoDir <= 1'b1;
                                state <= READ;
                            end
                            else begin
                                dsIoDir <= 1'b0;
                                state <= WRITE;
                            end
                        end
                    end
                end

                // Read Mode (LSB first, SCLK 하강 엣지 시프트)
                READ: begin
                    if (sclkFall) begin
                        dataShift <= dataShift >> 1;
                        dsOut <= dataShift[1];
                        bitCnt <= bitCnt + 1;

                        if (bitCnt == 7) begin
                            state <= IDLE;
                            dsIoDir <= 1'b0;
                        end
                    end
                end

                // Write Mode (LSB fist, SCLK 상승 엣지 샘플링)
                WRITE: begin
                    if (sclkRise) begin
                        dataShift[bitCnt] <= dsData;
                        bitCnt <= bitCnt + 1;

                        if (bitCnt == 7) begin
                            case (cmdShift[7:1])
                                7'h40: rtcMem[0] <= dataShift;
                                7'h41: rtcMem[1] <= dataShift;
                                7'h42: rtcMem[2] <= dataShift;
                                7'h43: rtcMem[3] <= dataShift;
                                7'h44: rtcMem[4] <= dataShift;
                                7'h45: rtcMem[5] <= dataShift;
                                7'h46: rtcMem[6] <= dataShift;
                            endcase

                            state <= IDLE;
                        end
                    end
                end
            endcase
        end
    end

    // 사용자 동작 시뮬레이션
    initial begin
        rst = 1;
        btnR = 0; sw = 0; reA = 0; reB = 0; reBtn = 0;

        $display("======================================================================================================");
        $display("                    Simulation Start: Top Level DS1302 Verification                                   ");
        $display("                    Scenario: Init Hour(12) Read -> Edit(13) and Save -> Final Read(13)               ");
        $display("======================================================================================================");

        #100 rst = 1'b0;
        $display("[%0t] Reset Released", $time);
        #1000;

        // Step 1: 초기값(12) 읽기
        $display("[%0t] [Step 1] Initial RTC Read Triggered", $time);
        force dut.tick1s = 1'b1;
        #10 force dut.tick1s = 1'b0;
        
        #1120000;
        $display("[%0t] [Step 1 Check] Hour Read DUT: %h (Expected: 12)", $time, dut.u_rtcRead.hrsData);
        #1000;

        // Step 2: 시간 편집 및 저장 (12 -> 13)
        sw = 7'b0000100;
        $display("[%0t] [Step 2-1] Enter Hours Edit Mode", $time);
        #1000;

        $display("[%0t] [Step 2-2] Rotary CW (Increment Hour 12 -> 13)", $time);
        force dut.reCw = 1'b1;
        #20 force dut.reCw = 1'b0;
        #1000;

        $display("[%0t] [Step 2-3] Press Rotary Button (Save)", $time);
        force dut.reBtnEdge = 1'b1;
        #20 force dut.reBtnEdge = 1'b0;

        $display("[%0t] [Wait] Waiting for Write Sequence to Complete...", $time);
        #600000;
        $display("[%0t] [Step 2 Check] RTC Memory Hour Value: %h (Expected: 13)", $time, rtcMem[2]);
        #1000;

        // Step 3: 변경된 값(13) 읽기
        sw = 7'b0000000;
        $display("[%0t] [Step 3] Verification Read Triggered", $time);
        force dut.tick1s = 1'b1;
        #10 force dut.tick1s = 1'b0;

        #50000;
        $display("[%0t] [Step 3 Check] Hour Read DUT: %h (Expected: 13)", $time, dut.u_rtcRead.hrsData);

        // 최종 확인
        $display("------------------------------------------------------------------------------------------------------");
        $display("                                Final Result Check (Read updated time)                                ");
        $display("RTC Memory Addr 84 (Hour): %h", rtcMem[2]);
        $display("Top Module Read Hrs: %h", dut.u_rtcRead.hrsData);
        $display("------------------------------------------------------------------------------------------------------");
        
        $finish;
    end

endmodule
