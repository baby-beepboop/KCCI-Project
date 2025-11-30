module top_ds1302(
    input clk, rst,

    output sclk, ce,
    inout  dsData,

    input       btnR,
    input [6:0] sw,
    input       reA, reB, reBtn,

    output [15:0] led,
    output  [3:0] an,
    output  [6:0] seg,
    output        dp,

    input  RsRx,
    output RsTx
    );

    // tickGen 출력
    wire tick1s, tick1ms;

    // debouncer 출력
    wire btnPulse;
    wire reAdb, reBdb, reBtnDb;

    // 로터리 입력 펄스
    wire reCw, reCcw, reBtnEdge;

    // ds1302write 입출력
    wire writeEn;
    wire [7:0] writeAddr, writeIn;
    wire writeCe, writeIoDir, writeDone;
    wire writeOut;

    // ds1302read 입출력
    wire readEn;
    wire readCe, readIoDir, readDone;
    wire readOut;
    wire [7:0] secData, minData, hrsData, dateData, monData, dayData, yrData;

    // fndCtrl 입력
    wire [3:0] fndD0, fndD1, fndD2, fndD3;
    wire [1:0] fndDot;

    // UART 출력
    wire [7:0] rxOut;

    // Serial Clock 생성
    sclkGen u_sclkGen (.clk100Mhz(clk), .rst(rst), .sclk(sclk));

    // DS1302 읽기 시작 트리거 생성 (1s 펄스)
    tickGen #(.TICK_FREQ(1)) u_tick1sGen (.clk100Mhz(clk), .rst(rst), .tick(tick1s));

    // FND 스캔 펄스 생성 (1ms)
    tickGen #(.TICK_FREQ(1000)) u_tick1msGen (.clk100Mhz(clk), .rst(rst), .tick(tick1ms));

    // 입력 Handling
    btnEdgeDetecter u_btnDebouncer (.clk(clk), .rst(rst), .tick(tick1ms), .btnRaw(btnR), .btnPulse(btnPulse));

    debounceRotary u_rotaryDebouncer (
        .clk(clk), .rst(rst), .tick(tick1ms), .btnRaw({reBtn, reB, reA}), .btnDb({reBtnDb, reBdb, reAdb}));
    
    rotary u_rotary (
        .clk(clk), .rst(rst), .s1(reAdb), .s2(reBdb), .key(reBtnDb), .cw(reCw), .ccw(reCcw), .keyEdge(reBtnEdge));

    // RTC 메인 컨트롤러
    rtcCtrl u_rtcCtrl (
        .clk(clk), .rst(rst),
        .btn(btnPulse), .mode(sw), .cw(reCw), .ccw(reCcw), .save(reBtnEdge),
        // from ds1302read
        .minData(minData), .hrsData(hrsData),
        .dateData(dateData), .monData(monData), .dayData(dayData), .yrData(yrData),
        // to ds1302write
        .writeEn(writeEn), .writeAddr(writeAddr), .writeData(writeIn),
        // to fndCtrl
        .fndD0(fndD0), .fndD1(fndD1), .fndD2(fndD2), .fndD3(fndD3), .fndDot(fndDot));

    // DS1302 쓰기 모듈
    ds1302write u_rtcWrite (
        .clk(clk), .rst(rst),
        .sclk(sclk), .dataIn(dsData),
        .en(writeEn), .addr(writeAddr), .dataByte(writeIn),
        .ce(writeCe), .ioDir(writeIoDir), .dataOut(writeOut),
        .done(writeDone));

    // DS1302 읽기 모듈
    assign readEn = tick1s;

    ds1302read u_rtcRead (
        .clk(clk), .rst(rst),
        .sclk(sclk), .dataIn(dsData),
        .en(readEn),
        .ce(readCe), .ioDir(readIoDir), .dataOut(readOut),
        .secData(secData), .minData(minData), .hrsData(hrsData),
        .dateData(dateData), .monData(monData), .dayData(dayData), .yrData(yrData),
        .done(readDone));

    // DS1302 CE
    assign ce = writeCe | readCe;

    // DS1302 Data I/O (Tristate Buffer Control)
    assign dsData = (writeIoDir) ? writeOut :
                    (readIoDir)  ? readOut : 1'bz;

    // FND 컨트롤러
    fndCtrl u_fndCtrl (
        .clk(clk), .rst(rst), .tick(tick1ms),
        .d0(fndD0), .d1(fndD1), .d2(fndD2), .d3(fndD3), .dot(fndDot),
        .an(an), .seg(seg), .dp(dp));

    // UART
    top_uart u_uart (
        .clk(clk), .rst(rst),
        .rtcSecData(secData), .rtcMinData(minData), .rtcHrsData(hrsData),
        .rtcDateData(dateData), .rtcMonData(monData), .rtcDayData(dayData), .rtcYrData(yrData),
        .rxIn(RsRx), .txOut(RsTx), .rxOut(rxOut), .led(led));

endmodule
