// tb_ds1302 v1.0.0: DS1302 FND 동작 확인
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

    // 가상 RTC 메모리 (0: Sec, 1: Min, 2: Hr, ...)
    reg [7:0] rtcMem [0:31];

    top_ds1302 dut (
        .clk(clk), .rst(rst),
        .sclk(sclk), .ce(ce), .dsData(dsData),
        .btnR(btnR), .sw(sw), .reA(reA), .reB(reB), .reBtn(reBtn),
        .an(an), .seg(seg), .dp(dp),
        .RsRx(), .RsTx());

    initial clk = 0;
    always #5 clk = ~clk;

    reg sclkPrev;
    always @(posedge clk) sclkPrev <= sclk;

    // DS1302 Chip Model
    reg [7:0] cmdReg, dataReg;
    reg       readCmd;
    reg [3:0] bitCnt;

    localparam IDLE=0, CMD=1, WRITE=2, READ=3;
    reg [1:0] state;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            dsIoDir <= 0;
            bitCnt <= 0; cmdReg <= 0; dataReg <= 0;
            rtcMem[0] = 8'h00; rtcMem[1] = 8'h00; rtcMem[2] = 8'h12;
            $display("[%0t] [Model] RTC Memory Init: Sec=%h, Min=%h, Hr=%h", $time, rtcMem[0], rtcMem[1], rtcMem[2]);
        end
        else if (!ce) begin    // CE Low: 통신 초기화
            state <= IDLE;
            dsIoDir <= 0;
            bitCnt <= 0; cmdReg <= 0; dataReg <= 0;
            $display("[%0t] [Model] CE Low. State Reset to IDLE. dsIoDir=0 (Input/High-Z)", $time);
        end

        // CE High: 통신 활성화
        else begin
            // SCLK 상승 엣지: DUT -> RTC 방향 데이터 샘플링
            if (sclk && !sclkPrev) begin
                case (state)
                    IDLE: begin
                        state <= CMD;
                        bitCnt <= 0;
                        cmdReg[0] <= dsData;
                        $display("[%0t] [Model] Start CMD receive. bit=%b", $time, dsData);
                    end

                    CMD: begin
                        bitCnt <= bitCnt + 1;
                        cmdReg[bitCnt] <= dsData;
                        if (bitCnt == 7) begin
                            readCmd = cmdReg[0];
                            $display("[%0t] [Model] CMD Received: %h (RW Bit: %b)", $time, cmdReg, cmdReg[0]);
                            
                            bitCnt <= 0;
                            // Read 명령
                            if (cmdReg[7:1]) begin
                                case (cmdReg[7:1])
                                    7'h40: dataReg = rtcMem[0];    // Sec
                                    7'h41: dataReg = rtcMem[1];    // Min
                                    7'h42: dataReg = rtcMem[2];    // Hr
                                    default: dataReg = 8'h00;
                                endcase
                                dsIoDir <= 1'b1;        // Read Mode: Output Enable
                                dsOut <= dataReg[0];    // LSB 출력
                                state <= READ;
                                $display("[%0t] [Model] READ CMD! dsIoDir=1 (Output Enable). Sending Data=%h (LSB=%b)",
                                         $time, dataReg, dataReg[0]);
                            end

                            // Write 명령
                            else begin
                                state <= WRITE;
                                dsIoDir <= 1'b0;
                                $display("[%0t] [Model] WRITE CMD! dsIoDir=0 (Input/High-Z)", $time);
                            end
                        end
                    end

                    // Write Mode: 데이터 수신
                    WRITE: begin
                        dataReg[bitCnt] <= dsData;
                        bitCnt <= bitCnt + 1;
                        if (bitCnt == 7) begin
                            case (cmdReg[7:1])
                                7'h40: rtcMem[0] <= dataReg;
                                7'h41: rtcMem[1] <= dataReg;
                                7'h42: rtcMem[2] <= dataReg;
                            endcase
                            $display("[%0t] [Model] WRITE DONE! Addr=%h Data=%h", $time, cmdReg, dataReg);
                        
                            state <= IDLE;
                            bitCnt <= 0;
                        end
                    end

                    // Read Mode: 데이터 전송
                    READ: begin
                        bitCnt <= bitCnt + 1;
                        if (bitCnt == 7) begin
                            state <= IDLE;
                            dsIoDir <= 1'b0;
                            bitCnt <= 0;
                            $display("[%0t] [Model] READ DONE! dsIoDir=0 (Input/High-Z)", $time);
                        end
                    end
                endcase
            end

            // SLCK 하강 엣지: RTC -> DUT 방향 데이터 시프트 (READ 모드)
            if (!sclk && sclkPrev) begin
                if (state == READ) begin
                    dataReg <= dataReg >> 1;
                    dsOut <= cmdReg[1];
                    $display("[%0t] [Model] READ SHIFT. Next bit=%b, dataReg=%h", $time, dataReg[1], (dataReg >> 1));
                end
            end
        end
    end

    always @(sclk or ce) begin
        if (ce) begin
            if (sclk != sclkPrev) begin
                $display("[%0t] [MONITOR] SCLK %s, dsData=%b, DUT ioDir=%b, TB dsIoDir=%b",
                         $time, sclk ? "RISING" : "FALLING", dsData, dut.u_rtcRead.ioDir, dsIoDir);
            end
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
        
        #320000;
        $display("[%0t] [Step 1 Check] Hour Read DUT: %h (Expected: 12)", $time, dut.u_rtcRead.hrsData);
        #1000;

        // Step 2: 시간 편집 및 저장 (12 -> 13)
        sw = 7'b0000010;
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
        #100000;
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
