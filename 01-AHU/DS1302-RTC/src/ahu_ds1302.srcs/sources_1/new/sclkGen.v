// sclkGen v1.0.0: 100MHz 시스템 clock으로 100kHz SCLK를 생성하는 clock 분주기
module sclkGen(
    input clk100Mhz, rst,
    
    output reg sclk
    );

    // 100M / 100k = 1000, 50% 듀티 사이클을 위해 500 카운트
    localparam CNT_MAX = 500 - 1;
    localparam CNT_WIDTH = $clog2(CNT_MAX + 1);    // = 9

    reg [CNT_WIDTH-1:0] cnt;

    always @(posedge clk100Mhz or posedge rst) begin
        if (rst) begin
            cnt <= 0;
            sclk <= 0;
        end
        
        else begin
            if (cnt == CNT_MAX) begin
                cnt <= 0;
                sclk <= ~sclk;
            end
            else begin
                cnt <= cnt + 1;
            end
        end
    end

endmodule
