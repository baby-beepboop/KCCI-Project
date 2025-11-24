// fndCtrl v1.0.0: rtcCtrl에서 결정된 BCD 데이터 표시
module fndCtrl(
    input clk, rst,
    input tick,

    input [3:0] d0, d1, d2, d3,
    input [1:0] dot,

    output reg [3:0] an,
    output reg [6:0] seg,
    output reg       dp
    );

    reg [1:0] sel;
    reg [3:0] digit;

    // 다이나믹 스캔
    always @(posedge clk, posedge rst) begin
        if (rst) sel <= 0;
        else if (tick) sel <= sel + 1;
    end

    // 자리 선택 및 데이터 선택
    always @(*) begin
        an = 4'b1111;
        digit = 0;
        dp = 1;

        case (sel)
            2'd0: begin an = 4'b1110; digit = d0; dp = dot[0]; end
            2'd1: begin an = 4'b1101; digit = d1; dp = 1'b1; end
            2'd2: begin an = 4'b1011; digit = d2; dp = dot[1]; end
            2'd3: begin an = 4'b0111; digit = d3; dp = 1'b1; end
            default: begin an = 4'b1111; digit = 0; dp = 1; end
        endcase
    end

    // BCD to 7-Segment 디코더
    always @(*) begin
        case (digit)
            4'd0: seg = 7'b100_0000;
            4'd1: seg = 7'b111_1001;
            4'd2: seg = 7'b010_0100;
            4'd3: seg = 7'b011_0000;
            4'd4: seg = 7'b001_1001;
            4'd5: seg = 7'b001_0010;
            4'd6: seg = 7'b000_0010;
            4'd7: seg = 7'b111_1000;
            4'd8: seg = 7'b000_0000;
            4'd9: seg = 7'b001_0000;
            default: seg = 7'b111_1111;
        endcase
    end

endmodule
