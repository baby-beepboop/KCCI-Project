`timescale 1ns / 1ps

module uart2cmd(
    input clk,
    input reset,
    input [7:0] rx_data,
    input rx_done,
    output cmd_runstop,
    output cmd_clear,
    output cmd_mode,
    output cmd_status,
    output cmd_set1234
);

typedef enum logic [2:0] {IDLE, P_SLASH, P_S, P_E, P_T, P_1, P_2, P_3} parsing_cmd;
parsing_cmd c_state, n_state;

logic c_cmd_runstop, c_cmd_clear, c_cmd_mode, c_cmd_status, c_cmd_set1234;
logic n_cmd_runstop, n_cmd_clear, n_cmd_mode, n_cmd_status, n_cmd_set1234;

assign cmd_runstop = c_cmd_runstop;
assign cmd_clear = c_cmd_clear;
assign cmd_mode = c_cmd_mode;
assign cmd_status = c_cmd_status;
assign cmd_set1234 = c_cmd_set1234;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            c_state <= IDLE;
            c_cmd_runstop <= 0;
            c_cmd_clear <= 0;
            c_cmd_mode <= 0;
            c_cmd_status <= 0;
            c_cmd_set1234 <= 0;
        end else begin
            c_state <= n_state;
            c_cmd_runstop <= n_cmd_runstop;
            c_cmd_clear <= n_cmd_clear;
            c_cmd_mode <= n_cmd_mode;
            c_cmd_status <= n_cmd_status;
            c_cmd_set1234 <= n_cmd_set1234;
        end
    end

    always_comb begin
        n_state = c_state;
        n_cmd_runstop = 0;
        n_cmd_clear = 0;
        n_cmd_mode = 0;
        n_cmd_status = 0;
        n_cmd_set1234 = 0; 

        case (c_state)
            IDLE : begin
                if (rx_done) begin
                    if (rx_data == "/") begin
                        n_state = P_SLASH;
                    end else begin
                        n_state = IDLE;
                        case (rx_data)
                            "R", "r" : begin n_cmd_runstop = 1; end
                            "C", "c" : begin n_cmd_clear = 1; end
                            "M", "m" : begin n_cmd_mode = 1; end
                            "S", "s" : begin n_cmd_status = 1; end                       
                        endcase
                    end
                end
            end 
            P_SLASH : begin
                if (rx_done) begin
                    if (rx_data == "s") begin
                        n_state = P_S;
                    end else begin
                        n_state = IDLE;
                    end
                end

            end 
            P_S : begin
                if (rx_done) begin
                    if (rx_data == "e") begin
                        n_state = P_E;
                    end else begin
                        n_state = IDLE;
                    end
                end
            end 
            P_E : begin
                if (rx_done) begin
                    if (rx_data == "t") begin
                        n_state = P_T;
                    end else begin
                        n_state = IDLE;
                    end
                end
            end 
            P_T : begin
                if (rx_done) begin
                    if (rx_data == "1") begin
                        n_state = P_1;
                    end else begin
                        n_state = IDLE;
                    end
                end
            end 
            P_1 : begin
                if (rx_done) begin
                    if (rx_data == "2") begin
                        n_state = P_2;
                    end else begin
                        n_state = IDLE;
                    end
                end
            end 
            P_2 : begin
                if (rx_done) begin
                    if (rx_data == "3") begin
                        n_state = P_3;
                    end else begin
                        n_state = IDLE;
                    end
                end
            end
            P_3 : begin
                if (rx_done) begin
                    if (rx_data == "4") begin
                        n_cmd_set1234 = 1;
                        n_state = IDLE;
                    end else begin
                        n_state = IDLE;
                    end
                end
            end

        endcase
    end
         
endmodule

