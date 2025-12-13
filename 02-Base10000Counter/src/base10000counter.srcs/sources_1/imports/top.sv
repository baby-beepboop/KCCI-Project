// 만진 카운터: 3가지 입력으로 만진 카운터 조작 (Run/Stop, Clear, Counter Mode)
// v1.0.0: tick 생성기, 버튼 디바운서, FSM, 업다운 카운터, FND 제어, *UART* 로직 포함
// UART: 9600bps를 16배 오버샘플링한 Tx와 Rx 및 PC에서 전송한 명령어 디코더
module top(
    input clk, rst,

    input        runStop, clear, mode,
    output [3:0] an,
    output [6:0] seg,

    input  rxIn,
    output txOut
    );

    wire tick100k;
    wire runStopDb, clearDb, modeDb;

    wire [3:0] sFlag;

    wire [13:0] cnt;

    wire [7:0] txIn;
    wire txBusy, txDone;
    wire [7:0] rxOut;

    wire runStopCmd, clearCmd, modeCmd;

    tickGen u_tick100kGen (.clk(clk), .rst(rst), .tick(tick100k));

    btnDebouncer u_runStopDebouncer (.clk(clk), .rst(rst), .tick(tick100k), .btnRaw(runStop | runStopCmd), .btnDb(runStopDb));
    btnDebouncer u_clearDebouncer (.clk(clk), .rst(rst), .tick(tick100k), .btnRaw(clear | clearCmd), .btnDb(clearDb));
    btnDebouncer u_modeDebouncer (.clk(clk), .rst(rst), .tick(tick100k), .btnRaw(mode | modeCmd), .btnDb(modeDb));

    control_unit u_control_unit (.clk(clk), .rst(rst), .runStop(runStopDb), .clear(clearDb), .mode(modeDb), .sFlag(sFlag));

    counter_datapath u_counter_datapath (.clk(clk), .rst(rst), .sFlag(sFlag), .cnt(cnt));

    fndController u_fndController (.clk(clk), .rst(rst), .cnt(cnt), .an(an), .seg(seg));
     
    uart u_uart (
        .clk(clk), .rst(rst),
        .rxIn(rxIn), .txEn(txEn), .txIn(txIn),
        .rxOut(rxOut), .txBusy(txBusy), .txDone(txDone), .txOut(txOut));

    cmdDecoder u_cmdDecoder (
        .clk(clk), .rst(rst),
        .cmd(rxOut),
        .runStopCmd(runStopCmd), .clearCmd(clearCmd), .modeCmd(modeCmd),
        .txBusy(txBusy), .txDone(txDone), .txEn(txEn), .msg(txIn));

endmodule
