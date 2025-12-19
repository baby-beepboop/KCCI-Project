`timescale 1ns / 1ps

module cmd_manager(
    input clk,
    input reset,
    input btn_runstop,
    input btn_mode,
    input btn_clear,
    input cmd_runstop,
    input cmd_mode,
    input cmd_clear,
    output i_runstop,
    output i_mode,
    output i_clear
    );

    assign i_runstop = btn_runstop || cmd_runstop;
    assign i_mode = btn_mode || cmd_mode;
    assign i_clear = btn_clear || cmd_clear;


endmodule

