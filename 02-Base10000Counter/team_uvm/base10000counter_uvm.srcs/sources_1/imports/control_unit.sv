`timescale 1ns / 1ps

module control_unit (
    input  logic clk,
    input  logic reset,
    input  logic i_runstop,
    input  logic i_mode,
    input  logic i_clear,
    input logic i_set1234,
    output logic o_runstop,
    output logic o_mode,
    output logic o_clear,
    output logic o_set1234
);

    typedef enum logic [2:0] {
        RUN_UP,
        RUN_DOWN,
        STOP_UP,
        STOP_DOWN,
        CLEAR,
        SET_1234
    } STATE_B;

    STATE_B c_state, n_state;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            c_state <= RUN_UP;
        end else begin
            c_state <= n_state;
        end
    end

    always_comb begin
        n_state = c_state;
        o_runstop = 1'b0;   // 1 = RUN, 0 = STOP
        o_mode = 1'b0;      // 1 = DOWN, 0 = UP
        o_clear = 1'b0;     // 1 = clear pulse
        o_set1234 = 1'b0;   // 1 = 1234 set pulse

        case (c_state)
            RUN_UP: begin
                o_runstop = 1;
                o_mode = 0;
                if (i_clear) begin 
                    n_state = CLEAR; 
                end else if (i_set1234) begin
                    n_state = SET_1234;
                end else if (i_runstop) begin
                    n_state = STOP_UP;
                end else if (i_mode) begin
                    n_state = RUN_DOWN;
                end
            end

            RUN_DOWN: begin
                o_runstop = 1;
                o_mode = 1;
                if (i_clear) begin 
                    n_state = CLEAR;
                end else if (i_set1234) begin
                    n_state = SET_1234;
                end else if (i_runstop) begin
                    n_state = STOP_DOWN;
                end else if (i_mode) begin
                    n_state = RUN_UP;
                end
            end

            STOP_UP: begin
                o_runstop = 0;
                o_mode = 0;
                if (i_clear) begin
                    n_state = CLEAR;
                end else if (i_set1234) begin
                    n_state = SET_1234;
                end else if (i_runstop) begin
                    n_state = RUN_UP;
                end else if (i_mode) begin
                    n_state = STOP_DOWN;
                end
            end

            STOP_DOWN: begin
                o_runstop = 0;
                o_mode = 1;
                if (i_clear) begin 
                    n_state = CLEAR;
                end else if (i_set1234) begin
                    n_state = SET_1234;
                end else if (i_runstop) begin
                    n_state = RUN_DOWN;
                end else if (i_mode) begin
                    n_state = STOP_UP;
                end
            end

            CLEAR: begin
                o_clear = 1;
                o_runstop = 1;
                o_mode = 0;
                n_state = RUN_UP;
            end

            SET_1234: begin
                o_set1234 = 1;
                o_runstop = 1;
                o_mode = 0;
                n_state = RUN_UP;
            end
        endcase
    end

endmodule

