`timescale 1ns / 1ps

module uart_arbiter_wrap (
    input  logic clk,
    input  logic reset,
    input  logic rx,
    input  logic cmd_status,
    output logic tx
);

    logic [13:0] st_count   = 14'd1234;
    logic        st_mode    = 1'b0;
    logic        st_runstop = 1'b1;

    logic        tx_valid;
    logic [7:0]  tx_data;
    logic        tx_ready;

    status2uart u_status2uart (
        .clk        (clk),
        .reset      (reset),
        .st_count   (st_count),
        .st_mode    (st_mode),
        .st_runstop (st_runstop),
        .cmd_status (cmd_status),
        .tx_ready   (tx_ready),
        .tx_valid   (tx_valid),
        .status_data(tx_data)
    );

    uart_top u_uart_top (
        .clk      (clk),
        .reset    (reset),
        .rx       (rx),
        .tx_valid (tx_valid),
        .tx_data  (tx_data),
        .tx_ready (tx_ready),
        .rx_ready (1'b1),
        .rx_valid (),
        .rx_data  (),
        .tx       (tx)
    );

endmodule
