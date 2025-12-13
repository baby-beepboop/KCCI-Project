module uart(
    input clk, rst,

    input       rxIn,
    input       txEn,
    input [7:0] txIn,

    output [7:0] rxOut,
    output       txBusy, txDone,
    output       txOut
    );

    localparam BPS_VAL = 9600;

    wire baudTick;
    wire [3:0] baudTickCnt;

    wire rxDone;

    baudTickGen #(.BPS(BPS_VAL)) u_baudTickGen (
        .clk(clk), .rst(rst), .tick(baudTick), .tickCnt(baudTickCnt));

    rx #(.BPS(BPS_VAL)) u_uartRx (
        .clk(clk), .rst(rst),
        .baudTick(baudTick), .baudTickCnt(baudTickCnt),
        .dataIn(rxIn),
        .done(rxDone),
        .dataOut(rxOut));

    tx #(.BPS(BPS_VAL)) u_uartTx (
        .clk(clk), .rst(rst),
        .baudTick(baudTick), .baudTickCnt(baudTickCnt),
        .en(txEn), .dataIn(txIn),
        .busy(txBusy), .done(txDone),
        .dataOut(txOut));
    
endmodule
