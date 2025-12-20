`timescale 1ns / 1ps

module top_10000_counter (
    input        clk,
    input        reset,
    input        mode,
    input        clear,
    input        run_stop,
    input        rx,
    output       tx,

    output [3:0] fnd_com,
    output [7:0] fnd_data
);

    wire [13:0] w_counter;
    wire [7:0] rx_data;
    wire [7:0] status_data;
    wire btn_runstop, btn_mode, btn_clear;
    wire cmd_runstop, cmd_mode, cmd_clear, cmd_status, cmd_set1234;
    wire i_runstop, i_mode, i_clear;
    wire o_clear, o_mode, o_runstop, o_set1234;
    wire tx_valid, tx_ready, rx_valid, rx_ready;

   btn_debouncer u_btn_runstop (
        .clk  (clk),
        .reset(reset),
        .i_btn(run_stop),
        .o_btn(btn_runstop)
    );

    btn_debouncer u_btn_mode (
        .clk  (clk),
        .reset(reset),
        .i_btn(mode),
        .o_btn(btn_mode)
    );

    btn_debouncer u_btn_clear (
        .clk  (clk),
        .reset(reset),
        .i_btn(clear),
        .o_btn(btn_clear)
    );

    uart_top u_uart_top (
        .clk(clk),
        .reset(reset),
        .rx(rx),
        .tx_data(status_data),
        .tx_valid(tx_valid),
        .tx_ready(tx_ready),
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

    cmd_manager u_cmd_manager (
        .clk(clk),
        .reset(reset),
        .btn_runstop(btn_runstop),
        .btn_mode(btn_mode),
        .btn_clear(btn_clear),
        .cmd_runstop(cmd_runstop),
        .cmd_mode(cmd_mode),
        .cmd_clear(cmd_clear),
        .i_runstop(i_runstop),
        .i_mode(i_mode),
        .i_clear(i_clear)
    );

    status2uart u_status2uart (
        .clk(clk),
        .reset(reset),
        .st_count(w_counter),
        .st_mode(o_mode),
        .st_runstop(o_runstop),
        .cmd_status(cmd_status),
        .tx_ready(tx_ready),
        .tx_valid(tx_valid),
        .status_data(status_data)
    );

    control_unit u_control_unit (
        .clk(clk),
        .reset(reset),
        .i_runstop(i_runstop),
        .i_mode(i_mode),
        .i_clear(i_clear),
        .i_set1234(cmd_set1234),
        .o_runstop(o_runstop),
        .o_mode(o_mode),
        .o_clear(o_clear),
        .o_set1234(o_set1234)
    );

    datapath_counter u_datapath_counter (
        .clk(clk),
        .reset(reset),
        .mode(o_mode),
        .clear(o_clear),
        .run_stop(o_runstop),
        .set_1234(o_set1234),
        .counter(w_counter)
    );

    fnd_controller u_fnd_controller (
        .clk(clk),
        .reset(reset),
        .counter(w_counter),
        .fnd_com(fnd_com),
        .fnd_data(fnd_data)
    );

endmodule

// Data Processing
module datapath_counter (
    input clk,
    input reset,
    input mode,
    input clear,
    input run_stop,
    input set_1234,
    output [13:0] counter
);

    wire w_tick;
    counter_10000 u_counter (
        .clk(clk),
        .reset(reset),
        .tick(w_tick),
        .mode(mode),
        .clear(clear),
        .run_stop(run_stop),
        .set_1234(set_1234),
        .counter(counter)
    );

    clk_div1 u_clk_div1 (
        .clk  (clk),
        .reset(reset),
        .tick (w_tick)
    );

endmodule


