`timescale 1ns / 1ps

module uart_rx #( 
    parameter BPS = 9600
) (
    input              clk,
    input              reset,
    input              rx,
    output reg  [7:0]  data_out,
    output reg         rx_done
    );

    parameter 
        IDLE = 2'b00,
        START_BIT = 2'b01,
        DATA_BITS = 2'b10,
        STOP_BIT  = 2'b11;
    
    parameter integer DIVIDER_COUNT = 100_000_000 / (BPS * 16);

    reg [1:0] r_state;     // state: IDLE START_BIT DATA_BITS STOP_BIT
    reg [3:0] r_bit_cnt;   // r_data_reg에 들어갈 index값
    reg [7:0] r_data_reg;  //rx포트로 부터 들어온 bit를 담을 그릇
    reg [15:0] r_baud_cnt; // 651ns : 9600x16 오버샘플링(16) count변수
    reg        r_baud_tick;  // 651ns 마다 tick 발생 
    reg [3:0]  r_baud_tick_cnt;  // 16개 오버샘플링값 count


   always @(posedge clk, posedge reset) begin
        if (reset) begin
            r_baud_cnt <= 0;
            r_baud_tick <= 0;
        end else begin
            if (r_baud_cnt == DIVIDER_COUNT-1) begin
                r_baud_cnt <= 0;
                r_baud_tick <= 1; 
            end else begin
                r_baud_cnt <= r_baud_cnt + 1;
                r_baud_tick <= 0;
            end 
        end 
    end 

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_state <= IDLE;
            data_out <= 8'b0;
            rx_done <= 1'b0;
            r_bit_cnt <= 4'd0;
            r_data_reg <= 8'b0;
            r_baud_tick_cnt <= 4'd0;
        end else begin
            rx_done <= 1'b0;
            case (r_state)
                IDLE: begin
                    if (!rx) begin
                        r_state <= START_BIT;
                        r_baud_tick_cnt <= 4'd0;
                    end
                end
                
                START_BIT: begin
                    if (r_baud_tick) begin
                        r_baud_tick_cnt <= r_baud_tick_cnt + 1;
                        if (r_baud_tick_cnt == 4'd7) begin 
                            r_state <= DATA_BITS;
                            r_bit_cnt <= 4'd0;
                            r_baud_tick_cnt <= 4'd0;
                        end
                    end
                end

                DATA_BITS: begin
                    if (r_baud_tick) begin
                        r_baud_tick_cnt <= r_baud_tick_cnt + 1;
                        if (r_baud_tick_cnt == 4'd15) begin
                            r_data_reg[r_bit_cnt] <= rx;
                            r_baud_tick_cnt <= 4'd0;
                            if (r_bit_cnt == 4'd7) begin
                                r_state <= STOP_BIT;
                            end else begin
                                r_bit_cnt <= r_bit_cnt + 1;
                            end
                        end
                    end
                end
                
                STOP_BIT: begin
                    if (r_baud_tick) begin
                        r_baud_tick_cnt <= r_baud_tick_cnt + 1;
                        if (r_baud_tick_cnt == 4'd15) begin
                            r_state <= IDLE;
                            data_out <= r_data_reg;
                            rx_done <= 1'b1;
                        end
                    end
                end
                default: r_state <= IDLE;
            endcase
        end
    end
endmodule