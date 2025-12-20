`timescale 1ns / 1ps

module uart_top_to_uart2cmd (
    input  clk,
    input  reset,
    input  rx,
    output tx,
    output cmd_runstop,
    output cmd_clear,
    output cmd_mode,
    output cmd_status,
    output cmd_set1234
);

    wire [7:0] rx_data;
    wire rx_valid, rx_ready;

    uart_top u_uart_top (
        .clk(clk),
        .reset(reset),
        .rx(rx),
        .tx_data(8'h00),
        .tx_valid(1'b0),
        .tx_ready(),
        .rx_ready(rx_ready),
        .rx_valid(rx_valid),
        .rx_data(rx_data),
        .tx(tx)
    );

    uart2cmd u_uart2cmd (
        .clk(clk),
        .reset(reset),
        .rx_data(rx_data),
        .rx_valid(rx_valid),
        .rx_ready(rx_ready),
        .cmd_runstop(cmd_runstop),
        .cmd_clear(cmd_clear),
        .cmd_mode(cmd_mode),
        .cmd_status(cmd_status),
        .cmd_set1234(cmd_set1234)
    );

endmodule
