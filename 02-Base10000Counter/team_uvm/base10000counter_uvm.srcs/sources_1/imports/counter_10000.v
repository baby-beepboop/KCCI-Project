`timescale 1ns / 1ps

// 100ms마다 1 tick
// mode: 0일때 up, 1일때 down counter
// clear: 0일때 normal 동작, 1일때 fnd clear
// run_stop: 0일때 counter stop, 1일때 다시 동작
module counter_10000 (
    input clk,
    input reset,
    input tick,
    input mode,
    input clear,
    input run_stop,
    input set_1234,
    output reg [13:0] counter
);

    parameter TCOUNT = 10_000;

    always @(posedge clk, posedge reset) begin

        if (reset) begin
            counter <= 0;
        end else begin
            if (run_stop) begin
                if (!clear) begin  // clear가 0일 때
                    if (!set_1234) begin
                        if (mode == 1'b0) begin
                        // up count
                        if (tick) begin
                            if (counter == 14'd9999) begin
                                counter <= 0;
                            end else begin
                                counter <= counter + 1;
                            end
                        end
                    end else begin
                        // down count
                        if (tick) begin
                            if (counter == 0) begin
                                counter <= 14'd9999;
                            end else begin
                                counter <= counter - 1;
                            end
                        end
                    end
                    end else begin
                        counter <= 14'd1234;
                    end                    
                end else begin
                    counter <= 0;
                end
            end else counter <= counter;

        end
    end

endmodule


