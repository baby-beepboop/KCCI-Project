// tb_rtcInteg v1.0.0: Hour Edit Mode에서 Hour 값 편집 후 저장 동작 확인
`timescale 1ns / 1ps

module tb_rtcInteg;
    reg clk, rst;

    // rtcCtrl 입력
    reg btn;
    reg [6:0] mode;
    reg cw, ccw, save;

    // RTC Data 입력 (RTC에서 읽어온 값이라고 가정)
    reg [7:0] hrsData;

    wire sclk;

    // rtcCtrl 출력
    wire writeEn;
    wire [7:0] writeAddr, writeIn;

    // ds1302write 출력
    wire writeCe, writeIoDir, writeDone;
    wire writeOut;

    // Tri-state IO Line
    wire dsIoDir;

    sclkGen u_sclkGen (.clk100Mhz(clk), .rst(rst), .sclk(sclk));

    rtcCtrl u_rtcCtrl (
        .clk(clk), .rst(rst),
        .btn(btn), .mode(mode), .cw(cw), .ccw(ccw), .save(save),
        // from ds1302read
        .minData(), .hrsData(hrsData), .dateData(), .monData(), .dayData(), .yrData(),
        // to ds1302write
        .writeEn(writeEn), .writeAddr(writeAddr), .writeData(writeIn),
        // to fndCtrl
        .fndD0(), .fndD1(), .fndD2(), .fndD3(), .fndDot());

    ds1302write u_rtcWrite (
        .clk(clk), .rst(rst),
        .en(writeEn), .addr(writeAddr), .dataIn(writeIn),
        .sclk(sclk), .ce(writeCe),
        .ioDir(writeIoDir), .dataOut(writeOut),
        .done(writeDone));

    assign dsIoDir = (writeIoDir) ? writeOut : 1'bz;

    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin
        rst = 1;
        mode = 0;
        btn = 0; cw = 0; ccw = 0; save = 0;
        hrsData = 8'h12;

        $display("=====================================================================================================");
        $display("                            Simulation Start: RTC Write Intergration Test                            ");
        $display("=====================================================================================================");

        #100 rst = 1'b0;
        $display("[%0t] Reset released", $time);

        // Step 1: Hour Edit Mode 진입 (mode[1] = 1)
        #100 mode = 7'b0000010;
        $display("[%0t] Mode Changed: Hour Edit Mode (mode[1]=1)", $time);
        #100;

        // Step 2: 로터리 입력을 통해 Hour 값을 1로 변경
        cw = 1'b1;
        #10 cw = 1'b0;
        $display("[%0t] Rotary CW Rotation (Request to Increase Value)", $time);
        #50;

        // Step 3: save 버튼 입력 (저장)
        $display("[%0t] Press SAVE Button", $time);
        save = 1'b1;
        #10 save = 1'b0;
        #50;

        // Step 4: Write 동작 관찰
        if (writeEn) begin
            $display("[%0t] SUCCSSED: 'writeEn' asserted!", $time);
            $display("      -> Target Address: %h (Expected Value: 84)", writeAddr);
            $display("      -> Write Data:     %h (Expected Value: 01)", writeIn);
        end
        else begin
            $display("[%0t] FAILURE: 'writeEn' signal failed to assert!", $time);
        end

        wait(writeDone);
        $display("[%0t] DS1302 Write Done (writeDone=1)", $time);

        #500 $finish;
    end

endmodule
