`timescale 1ns / 1ps

module fnd_controller (
    input         clk,
    input         reset,
    input  [13:0] counter,
    output [ 3:0] fnd_com,
    output [ 7:0] fnd_data
);

    wire [1:0] w_sel;
    wire [3:0] w_bcd;
    wire [3:0] w_digit_1, w_digit_10, w_digit_100, w_digit_1000;
    wire w_tick_400hz;

    clk_div_400hz u_clk_div_400hz (
        .clk  (clk),
        .reset(reset),
        .tick (w_tick_400hz)
    );

    counter_4 u_counter_4 (  // 4진 카운터
        .clk  (w_tick_400hz),
        .reset(reset),
        .sel  (w_sel)
    );

    decoder_2x4 u_decoder_2x4 (  // 2x4 decoder
        .sel(w_sel),
        .fnd_com(fnd_com)
    );

    digit_splitter u_digit_splitter (
        .counter(counter),
        .digit_1(w_digit_1),
        .digit_10(w_digit_10),
        .digit_100(w_digit_100),
        .digit_1000(w_digit_1000)
    );

    mux_4x1 u_mux_4x1 (
        .sel(w_sel),  // 2bit로 선언
        .digit_1(w_digit_1),
        .digit_10(w_digit_10),
        .digit_100(w_digit_100),
        .digit_1000(w_digit_1000),
        .bcd(w_bcd)
    );

    bcd u_bcd (
        .bcd(w_bcd),
        .fnd_data(fnd_data)
    );

endmodule

module clk_div_400hz (  // 400hz tick(sel) 생성
    input  clk,
    input  reset,
    output tick
);

    parameter FCOUNT = 100_000_000 / 400;
    reg [$clog2(FCOUNT)-1:0] r_counter;
    reg r_tick;
    assign tick = r_tick;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            r_counter <= 0;
            r_tick <= 1'b0;
        end else begin
            if (r_counter == FCOUNT - 1) begin
                r_counter <= 0;
                r_tick <= 1'b1;
            end else begin
                r_counter <= r_counter + 1;
                r_tick <= 0;
            end
        end

    end

endmodule

// for generating 400hz sel
module counter_4 (
    input        clk,
    input        reset,
    output [1:0] sel
);

    reg [2:0] r_counter;
    assign sel = r_counter;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            r_counter <= 0;
        end else begin
            r_counter <= r_counter + 1;
        end
    end

endmodule

// for digit select to fnd
module decoder_2x4 (
    input  [1:0] sel,
    output [3:0] fnd_com
);

    reg [3:0] r_fnd_com;
    assign fnd_com = r_fnd_com;

    always @(*) begin
        case (sel)
            2'b00:   r_fnd_com = 4'b1110;  // fnd com digit 1
            2'b01:   r_fnd_com = 4'b1101;  // fnd com digit 1
            2'b10:   r_fnd_com = 4'b1011;  // fnd com digit 1
            2'b11:   r_fnd_com = 4'b0111;  // fnd com digit 1
            default: r_fnd_com = 4'b1111;

        endcase

    end

endmodule

// digit splittting: counter를 받아서 자릿수 4개로 나눈다
module digit_splitter (
    input  [13:0] counter,
    output [ 3:0] digit_1,
    output [ 3:0] digit_10,
    output [ 3:0] digit_100,
    output [ 3:0] digit_1000
);

    assign digit_1 = counter % 10;
    assign digit_10 = (counter / 10) % 10;
    assign digit_100 = (counter / 100) % 10;
    assign digit_1000 = (counter / 1000) % 10;
endmodule

// 4 X 1 mux for digits selecting
module mux_4x1 (
    input [1:0] sel,  // 2bit로 선언
    input [3:0] digit_1,
    input [3:0] digit_10,
    input [3:0] digit_100,
    input [3:0] digit_1000,
    output [3:0] bcd
);

    reg [3:0] r_bcd;

    assign bcd = r_bcd;

    always @(*) begin   // always:항상, @: event, (): ~할때마다, (*): 모든 입력
        case (sel)
            2'b00: begin  // digit 1
                r_bcd = digit_1;
            end
            2'b01: begin  // digit 10
                r_bcd = digit_10;
            end
            2'b10: begin  // digit 100
                r_bcd = digit_100;
            end
            2'b11: begin  // digit 1000
                r_bcd = digit_1000;
            end
            // 2bit 입력의 모든 경우의 수가 다 있으므로 latch가 생기진 않음
            default: r_bcd = digit_1;
        endcase

    end

endmodule
//----------------------------------------------------------
// bcd값을 fnd에 출력하는 module
//----------------------------------------------------------
module bcd (
    input [3:0] bcd,
    output reg [7:0] fnd_data
);

    always @(bcd) begin  // bcd_data가 바뀔때는 언제나 실행한다.
        case (bcd)  // bcd_data에 올 수 있는 값은 0~9
            4'h0: fnd_data = 8'hc0;  // 0
            4'h1: fnd_data = 8'hf9;  // 1
            4'h2: fnd_data = 8'ha4;  // 2
            4'h3: fnd_data = 8'hb0;
            4'h4: fnd_data = 8'h99;
            4'h5: fnd_data = 8'h92;
            4'h6: fnd_data = 8'h82;
            4'h7: fnd_data = 8'hf8;
            4'h8: fnd_data = 8'h80;
            4'h9: fnd_data = 8'h90;  // 9
            4'ha: fnd_data = 8'h88;
            4'hb: fnd_data = 8'h83;
            4'hc: fnd_data = 8'hc6;
            4'hd: fnd_data = 8'ha1;
            4'he: fnd_data = 8'h7f;  // dot display
            4'hf: fnd_data = 8'hff;  // all off
            default: fnd_data = 8'hff;
        endcase
    end
endmodule
