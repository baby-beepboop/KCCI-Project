module fndCtrl(
    input clk, rst,
    input tick,

    input [13:0] segData,

    output reg [3:0] an,
    output     [6:0] seg
    );

    wire [3:0] d0, d1, d2, d3;

    reg [1:0] sel;

    reg [3:0] bcd;

    assign d0 = segData % 10;
    assign d1 = (segData / 10) % 10;
    assign d2 = (segData / 100) % 10;
    assign d3 = (segData / 1000) % 10;

    always @(posedge clk or posedge rst) begin
        if (rst) sel <= 0;
        else if (tick) sel <= sel + 1;
    end

    always @(*) begin
        case (sel)
            2'd0: begin an = 4'b1110; bcd = d0; end
            2'd1: begin an = 4'b1101; bcd = d1; end
            2'd2: begin an = 4'b1011; bcd = d2; end
            2'd3: begin an = 4'b0111; bcd = d3; end
            default: begin an = 4'b1111; bcd = 0; end
        endcase
    end

    bcdDecoder u_bcdDecoder (.bcd(bcd), .dec(seg));

endmodule

module bcdDecoder (
    input [3:0] bcd,
    output reg [6:0] dec
    );

    always @(bcd) begin
        case (bcd)
            4'd0: dec = 7'b100_0000;
            4'd1: dec = 7'b111_1001;
            4'd2: dec = 7'b010_0100;
            4'd3: dec = 7'b011_0000;
            4'd4: dec = 7'b001_1001;
            4'd5: dec = 7'b001_0010;
            4'd6: dec = 7'b000_0010;
            4'd7: dec = 7'b111_1000;
            4'd8: dec = 7'b000_0000;
            4'd9: dec = 7'b001_0000;
            default: dec = 7'b111_1111;
        endcase
    end

endmodule
