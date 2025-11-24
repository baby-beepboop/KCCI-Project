module top_ds1302(
    input clk, rst,

    output sclk, ce,
    inout  dsData,

    input       btnR,
    input [5:0] sw,

    output [15:0] led,
    output  [3:0] an,
    output  [6:0] seg,
    output        dp,

    input  RsRx,
    output RsTx
    );

    wire tick1s, tick1ms;

    wire btnPulse;

    wire [3:0] fndD0, fndD1, fndD2, fndD3;
    wire [1:0] fndDot;

    wire readEn;
    wire readIn;
    wire ioDir, readOut;

    wire [7:0] secData, minData, hrsData, dateData, monData, dayData, yrData;

    wire readDone;

    wire [7:0] rxOut;

    // Serial Clock 생성
    sclkGen u_sclkGen (.clk100Mhz(clk), .rst(rst), .sclk(sclk));

    // DS1302 읽기 시작 트리거 생성 (1s 펄스)
    tickGen #(.TICK_FREQ(1)) u_tick1sGen (.clk100Mhz(clk), .rst(rst), .tick(tick1s));

    // FND 스캔 펄스 생성 (1ms)
    tickGen #(.TICK_FREQ(1000)) u_tick1msGen (.clk100Mhz(clk), .rst(rst), .tick(tick1ms));

    // 입력 Handling
    btnEdgeDetecter u_btnDebouncer (.clk(clk), .rst(rst), .tick(tick1ms), .btnRaw(btnR), .btnPulse(btnPulse));

    // RTC 메인 컨트롤러
    rtcCtrl u_rtcCtrl (
        .clk(clk), .rst(rst),
        .btn(btnPulse), .mode(sw),
        // from ds1302read
        .minData(minData), .hrsData(hrsData),
        .dateData(dateData), .monData(monData), .dayData(dayData), .yrData(yrData),
        // to fndCtrl
        .fndD0(fndD0), .fndD1(fndD1), .fndD2(fndD2), .fndD3(fndD3), .fndDot(fndDot));

    // DS1302 읽기 모듈
    assign readEn = tick1s;
    assign readIn = dsData;

    ds1302read u_rtcRead (
        .clk(clk), .rst(rst), .en(readEn),
        .sclk(sclk), .ce(readCe), .dataIn(readIn),
        .ioDir(readIoDir), .dataOut(readOut),
        .secData(secData), .minData(minData), .hrsData(hrsData),
        .dateData(dateData), .monData(monData), .dayData(dayData), .yrData(yrData),
        .done(readDone));

    // DS1302 CE
    assign ce = readCe;

    // DS1302 Data I/O (Tristate Buffer Control)
    assign dsData = (readIoDir) ? readOut : 1'bz;

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
