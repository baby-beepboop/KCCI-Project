`timescale 1ns / 1ps

module fifo_tx(
    input clk,
    input reset,
    input wr,
    input rd,
    input [7:0] wdata,
    output [7:0] rdata,
    output full,
    output empty
    );

    wire [1:0] w_wptr, w_rptr;

    register_file u_register_file(
        .clk(clk),
        .waddr(w_wptr),
        .wdata(wdata),
        .raddr(w_rptr),
        .wr(~full & wr),    // if (!full & wr)
        .rdata(rdata)
    );

    fifo_control_unit u_fifo_control_unit(
        .clk(clk),
        .reset(reset),
        .wr(wr),
        .rd(rd),
        .w_ptr(w_wptr),
        .r_ptr(w_rptr),
        .full(full),
        .empty(empty)
);

endmodule
