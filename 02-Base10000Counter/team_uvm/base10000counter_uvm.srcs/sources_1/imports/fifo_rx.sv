`timescale 1ns / 1ps

module fifo_rx(
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


module register_file (
    input       clk,
    input [1:0] waddr,
    input [7:0] wdata,
    input [1:0] raddr,
    input       wr,
    output logic [7:0] rdata
);
    // data 8bits, size 4byte
    logic [7:0] register_file [0:3];

    always_ff @(posedge clk) begin
        // write, push
        if (wr) begin
            register_file[waddr] <= wdata;
        end 
    end

    // pop combinational logic
    assign rdata = register_file[raddr];
endmodule


module fifo_control_unit (
    input clk,
    input reset,
    input wr,
    input rd,
    output [1:0] w_ptr,
    output [1:0] r_ptr,
    output full,
    output empty
);

    logic c_full, n_full, c_empty, n_empty;
    logic [1:0] c_wptr, n_wptr, c_rptr, n_rptr;

    assign full = c_full;
    assign empty = c_empty;
    assign w_ptr = c_wptr;
    assign r_ptr = c_rptr;
    
    // state register logic
    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            c_full = 1'b0;
            c_empty = 1'b1;
            c_wptr = 2'b00;
            c_rptr = 2'b00;
        end else begin
            c_full <= n_full;
            c_empty <= n_empty;
            c_wptr <= n_wptr;
            c_rptr <= n_rptr;
        end
    end

    // next state logic
    always_comb begin
        n_full = c_full;
        n_empty = c_empty;
        n_rptr = c_rptr;
        n_wptr = c_wptr;
        case ({wr, rd})     // state wr, rd or push, pop
           2'b01: begin
                // pop
                n_full <= 1'b0;
                if (!c_empty) begin
                    n_rptr = c_rptr + 1;
                end
                if (c_wptr == n_rptr) begin
                    n_empty = 1'b1;
                end
            end

           2'b10: begin
                // push
                n_empty = 1'b0;
                if (!c_full) begin
                    n_wptr = c_wptr + 1;
                end
                if (c_rptr == n_wptr) begin
                    n_full = 1'b1;
                end
           end

           2'b11: begin
                // push_pop
                if (c_empty) begin
                    //  only push
                    n_empty = 1'b0;
                    n_wptr = c_wptr + 1;
                end else if (c_full) begin
                    //only pop
                    n_full = 1'b0;
                    n_rptr = c_rptr + 1;
                end else begin
                    // push & pop
                    n_wptr = c_wptr + 1;
                    n_rptr = c_rptr + 1;
                end
           end

        endcase
    end
    
endmodule