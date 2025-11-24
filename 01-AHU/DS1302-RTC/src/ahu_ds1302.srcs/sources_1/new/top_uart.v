module top_uart(
    input clk, rst,

    input [7:0] rtcSecData, rtcMinData, rtcHrsData, rtcDateData, rtcMonData, rtcDayData, rtcYrData,
    
    input rxIn,

    output       txOut,
    output [7:0] rxOut,
    
    output [15:0] led
    );

    localparam BPS_VAL = 9600;

    wire rtcTxTrig;

    wire txBusy, txDone;
    wire txEn;
    wire [7:0] txData;

    wire rxDone;

    txFormatter u_txFormatter (
        .clk(clk), .rst(rst),
        .trig(rtcTxTrig),
        .secData(rtcSecData), .minData(rtcMinData), .hrsData(rtcHrsData),
        .dateData(rtcDateData), .monData(rtcMonData), .dayData(rtcDayData), .yrData(rtcYrData),
        .busy(txBusy), .done(txDone),
        .txEn(txEn), .data(txData));

    txCore #(.BPS(BPS_VAL)) u_txCore (
        .clk(clk), .rst(rst), .en(txEn), .data(txData), .busy(txBusy), .done(txDone), .txOut(txOut));
    uart_rx #(.BPS(BPS_VAL)) u_rxCOre (.clk(clk), .reset(rst), .rx(rxIn), .rx_done(rxDone), .data_out(rxOut));

    cmdCtrl u_cmdCtrl (.clk(clk), .rst(rst), .rxDone(rxDone), .rxData(rxOut), .rtcTxReq(rtcTxTrig), .led(led));

endmodule
