`timescale 1ns / 1ps

// 10Hz tick
module clk_div1 (
    input  clk,
    input  reset,
    output tick
);
    parameter FCOUNT = 10_000_000; 

    reg [$clog2(FCOUNT)-1:0] r_count;
    reg r_tick;

    // 상승엣지가 발생할 때마다 count 증가 
    // count 9_999_999가 될때마다 tick 1 발생
    // 10_000_000 * 10ns = 100ms (10Hz tick)
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            r_count <= 0;
            r_tick  <= 0;
        end else if (r_count == FCOUNT - 1) begin
            r_tick  <= 1;
            r_count <= 0;
        end else begin
            r_tick  <= 0;
            r_count <= r_count + 1;
        end
    end

    assign tick = r_tick;

endmodule

