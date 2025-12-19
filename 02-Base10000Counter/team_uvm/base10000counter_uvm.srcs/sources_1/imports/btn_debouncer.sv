`timescale 1ns / 1ps

module btn_debouncer (
    input  clk,
    input  reset,
    input  i_btn,
    output o_btn
);

    // clk devider
    // 100MHz -> 100KHz
    parameter FCOUNT = 100_000_000 / 100_000;
    logic r_clk_100KHz;  // logic: 4상태 표현 Data type
    logic [$clog2(FCOUNT)-1:0] counter_100KHz;  
    // system verilog에선 wire, reg 구분없이 모두 logic으로 쓰기

    always_ff @(posedge clk, posedge reset) begin       // always를 써도 상관은 없음. always_ff는 순차논리를 표현
        if (reset) begin
            r_clk_100KHz   <= 1'b0;
            counter_100KHz <= 0;
        end else begin
            if (counter_100KHz == FCOUNT - 1) begin
                counter_100KHz <= 0;
                r_clk_100KHz   <= 1'b1;
            end else begin
                counter_100KHz <= counter_100KHz + 1;
                r_clk_100KHz   <= 1'b0;
            end
        end
    end

    // debounce 8FF-8input And gate 
    logic [7:0] shift_reg;
    logic debounce;

    // 8 SIPO(serial input parallel output) shift register
    always_ff @(posedge r_clk_100KHz, posedge reset) begin
        if (reset) begin
            shift_reg <= 8'h00;
        end else begin
            shift_reg <= {
                i_btn, shift_reg[7:1]
            };  // shift_reg[7:1]를 오른쪽으로 옮기고 MSB에 i_btn을 넣는다
        end
    end

    assign debounce = &(shift_reg);

    logic edge_detect;

    // rising edge detector
    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            edge_detect <= 1'b0;
        end else begin
            edge_detect <= debounce;
        end
    end

    assign o_btn = debounce & (~edge_detect);

endmodule

