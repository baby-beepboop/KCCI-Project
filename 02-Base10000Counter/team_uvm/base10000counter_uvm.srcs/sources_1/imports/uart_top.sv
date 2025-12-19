`timescale 1ns / 1ps

module uart_top (
    input        clk,
    input        reset,
    input        rx,
    input        tx_start,
    input  [7:0] tx_data,
    output       rx_done,
    output [7:0] rx_data,
    output       tx,
    output       tx_busy
);

    logic w_rxdone;
    logic fifo_rx_empty;
    logic c_fifo_rx_rd, n_fifo_rx_rd;
    logic fifo_tx_wr, fifo_tx_rd;
    logic fifo_tx_full, fifo_tx_empty;
    logic w_txstart;
    logic w_txbusy;
    logic fifo_rx_pulse;

    localparam BPS_VAL = 9600;
    wire baudTick;
    wire [3:0] baudTickCnt;

    logic [7:0] w_rxdata;
    logic [7:0] w_rdata;
    logic [7:0] w_txdata;
    logic [7:0] fifo_tx_wdata;

    assign n_fifo_rx_rd = ~fifo_tx_full & ~fifo_rx_empty;
    assign rx_data = w_rdata;
    assign rx_done = fifo_rx_pulse;
    assign fifo_tx_wr = fifo_rx_pulse | tx_start;
    assign fifo_tx_rd = ~w_txbusy & ~fifo_tx_empty;
    assign w_txstart = ~fifo_tx_empty;

    uart_rx #(.BPS(BPS_VAL)) u_uartRx (
        .clk(clk), .rst(reset),
        .baudTick(baudTick), .baudTickCnt(baudTickCnt),
        .dataIn(rx),
        .done(w_rxdone),
        .dataOut(w_rxdata));

    fifo_rx u_fifo_rx (
        .clk(clk),
        .reset(reset),
        .wr(w_rxdone),
        .rd(fifo_rx_pulse),
        .wdata(w_rxdata),
        .rdata(w_rdata),
        .full(),
        .empty(fifo_rx_empty)
    );

    fifo_tx u_fifo_tx (
        .clk(clk),
        .reset(reset),
        .wr(fifo_tx_wr),
        .rd(fifo_tx_rd),
        .wdata(fifo_tx_wdata),
        .rdata(w_txdata),
        .full(fifo_tx_full),
        .empty(fifo_tx_empty)
    );

    uart_tx #(.BPS(BPS_VAL)) u_uartTx (
        .clk(clk), .rst(reset),
        .baudTick(baudTick), .baudTickCnt(baudTickCnt),
        .en(w_txstart), .dataIn(w_txdata),
        .busy(w_txbusy), .done(),
        .dataOut(tx));

    baudTickGen #(.BPS(BPS_VAL)) u_baudTickGen (
    .clk(clk), .rst(reset), .tick(baudTick), .tickCnt(baudTickCnt));

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            c_fifo_rx_rd <= 0;
        end else begin
            c_fifo_rx_rd <= n_fifo_rx_rd;
        end
    end

    assign fifo_rx_pulse = ~c_fifo_rx_rd & n_fifo_rx_rd;

    assign fifo_tx_wdata = (tx_start) ? tx_data : w_rdata;

    assign tx_busy = fifo_tx_full;

endmodule

module baudTickGen #(
    parameter BPS = 9600
)(
    input clk, rst,

    output reg       tick,
    output reg [3:0] tickCnt
    );

    localparam CLKS_PER_BIT = 100_000_000 / (BPS * 16);    // = 651
    logic [$clog2(CLKS_PER_BIT)-1:0] clkCnt;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            clkCnt <= 0;
            tick <= 0;
            tickCnt <= 0;
        end

        else begin
            if (clkCnt == CLKS_PER_BIT - 1) begin
                clkCnt <= 0;
                tick <= 1'b1;
                tickCnt <= tickCnt + 1;
            end
            else begin
                clkCnt <= clkCnt + 1;
                tick <= 1'b0;
            end
        end
    end

endmodule