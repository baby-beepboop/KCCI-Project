`timescale 1ns / 1ps

module status2uart (
    input clk,
    input reset,
    input [13:0] st_count,
    input st_mode,
    input st_runstop,
    input cmd_status,
    input tx_busy,
    output logic [7:0] status_data,
    output logic tx_start
);

    typedef enum logic [1:0] {IDLE, WAIT, SEND} STATE_B;

    STATE_B c_state, n_state;
    logic [5:0] c_idx, n_idx;
    logic [7:0] mode_1, mode_2, mode_3, mode_4;
    logic [7:0] runstop_1, runstop_2, runstop_3, runstop_4;
    logic [3:0] count_1000, count_100, count_10, count_1;

    bin2bcd4digit u_bin2bcd4digit(
        .bin(st_count),
        .bcd_th(count_1000), 
        .bcd_hu(count_100),
        .bcd_te(count_10), 
        .bcd_on(count_1)  
    );

    always_comb begin
        if (!st_mode) begin
            mode_1 = "u";
            mode_2 = "p";
            mode_3 = " ";
            mode_4 = " ";
        end else begin
            mode_1 = "d";
            mode_2 = "o";
            mode_3 = "w";
            mode_4 = "n";
        end
    end

    always_comb begin
        if (st_runstop) begin
            runstop_1 = "r";
            runstop_2 = "u";
            runstop_3 = "n";
            runstop_4 = " ";
        end else begin
            runstop_1 = "s";
            runstop_2 = "t";
            runstop_3 = "o";
            runstop_4 = "p";
        end
    end

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            c_state <= IDLE;
            c_idx <= 0;
        end else begin
            c_state <= n_state;
            c_idx <= n_idx;
        end
    end

    always_comb begin

        n_state = c_state;
        n_idx = c_idx;
        tx_start = 0;
        status_data = 0;

        case (c_state)
            IDLE: begin
                if (cmd_status) begin
                    n_idx = 0;
                    n_state = WAIT;
                end
            end

            WAIT: begin
                if (!tx_busy) begin
                    tx_start = 1;
                    n_state = SEND;
                end
            end

            SEND: begin
                if (c_idx < 35) begin
                    n_state = WAIT;
                    n_idx = c_idx + 1;

                end else begin
                    n_state = IDLE;
                end
            end
        endcase

        case (c_idx)
            0: status_data = "c";
            1: status_data = "o";
            2: status_data = "u";
            3: status_data = "n";
            4: status_data = "t";
            5: status_data = ":";
            6: status_data = count_1000 +"0";
            7: status_data = count_100 + "0";
            8: status_data = count_10 + "0";
            9: status_data = count_1 + "0";
            10: status_data = " ";
            11: status_data = "m";
            12: status_data ="o";
            13: status_data = "d";
            14: status_data = "e";
            15: status_data = ":";
            16: status_data = mode_1;
            17: status_data = mode_2;
            18: status_data = mode_3;
            19: status_data = mode_4;
            20: status_data = "r";
            21: status_data = "u";
            22: status_data = "n";
            23: status_data = "_";
            24: status_data = "s";
            25: status_data = "t";
            26: status_data = "o";
            27: status_data = "p";
            28: status_data = ":";
            29: status_data = runstop_1;
            30: status_data = runstop_2;
            31: status_data = runstop_3;
            32: status_data = runstop_4;
            33: status_data = "\r";
            34: status_data = "\n";
        endcase
    end
    
endmodule

//==============================================================
// bin2bcd4digit (0~9999)
// Double Dabble 
//==============================================================
module bin2bcd4digit (
    input logic [13:0] bin,
    output logic [3:0] bcd_th, // thousands
    output logic [3:0] bcd_hu, // hundreds
    output logic [3:0] bcd_te, // tens
    output logic [3:0] bcd_on  // ones
);
    integer i;
    logic [29:0] shift;  // 14-bit + 16-bit(4 digits BCD)

    always_comb begin
        shift = '0;
        shift[13:0] = bin;

        for(i = 0; i < 14; i ++) begin
            // 각 BCD 자리가 5 이상이면 3 더하기 (Double Dabble 핵심)
            if (shift[17:14] >= 5) shift[17:14] = shift[17:14] + 3;  // ones
            if (shift[21:18] >= 5) shift[21:18] = shift[21:18] + 3;  // tens
            if (shift[25:22] >= 5) shift[25:22] = shift[25:22] + 3;  // hundreds
            if (shift[29:26] >= 5) shift[29:26] = shift[29:26] + 3;  // thousand

            shift = shift << 1;
        end

        bcd_th = shift[29:26];
        bcd_hu = shift[25:22];
        bcd_te = shift[21:18];
        bcd_on = shift[17:14];
    end

endmodule
