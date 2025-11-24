// rotary v1.0: 로터리 엔코더 입력을 받아 CW/CCW 펄스 생성
module rotary(
    input clk, rst,

    input s1, s2, key,
    output reg cw, ccw, keyEdge
    );

    reg [1:0] grayCode;

    localparam S00=2'b00, S01=2'b01, S11=2'b11, S10=2'b10;
    reg [1:0] cState, nState;

    reg keyPrev;

    // 동기화
    always @(posedge clk, posedge rst) begin
        if (rst) grayCode <= 0;
        else grayCode <= {s1, s2};
    end
    
    // FSM 상태 전이
    always @(posedge clk, posedge rst) begin
        if (rst) cState <= S00;
        else cState <= nState;
    end

    // 00 -> 01 -> 11 -> 10 :  CW
    // 00 -> 10 -> 11 -> 01 :  CCW
    always @(*) begin
        nState = cState;

        case (cState)
            S00: begin
                if (grayCode == 2'b01)      nState = S01;
                else if (grayCode == 2'b10) nState = S10;
            end
            S01: begin
                if (grayCode == 2'b11)      nState = S11;
                else if (grayCode == 2'b00) nState = S00;
            end
            S11: begin
                if (grayCode == 2'b10)      nState = S10;
                else if (grayCode == 2'b01) nState = S01;
            end
            S10: begin
                if (grayCode == 2'b00)      nState = S00;
                else if (grayCode == 2'b11) nState = S11;
            end
        endcase
    end

    // CW/CCW 펄스 생성
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cw <= 0;
            ccw <= 0;
        end
        
        else begin
            cw <= ((cState == S10) && (nState == S00));
            ccw <= ((cState == S01) && (nState == S00));
        end
    end

    // 버튼 엣지 검출
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            keyPrev <= 0;
            keyEdge <= 0;
        end
        else begin
            keyPrev <= key;
            keyEdge <= keyPrev & ~key;
        end
    end

endmodule
