// 4개의 FF 입력을 AND 연산하여 debounce 신호 생성
module btnDebouncer(
    input clk, rst,
    input tick,

    input btnRaw,
    output btnDb
    );

    logic [7:0] shiftReg;    // logic: 4가지 상태(High, Low, Unkown, High-Z) 표현. Verilog의 'wire', 'reg' 대체
    logic db;
    logic edgeDetect;

    // 8-SIPO(Serial Input Paraller Output) Shift Register
    always_ff @(posedge tick or posedge rst) begin    // always_ff: 순차 논리. always_comb: 조합 논리
        if (rst) shiftReg <= 0;
        else shiftReg <= {btnRaw, shiftReg[7:1]};
    end

    // 8-input AND gate
    assign db = &(shiftReg);    // &(a): a의 모든 비트를 AND한 1비트 결과 (Reduction AND 연산)

    // Rising Edge Detection
    always_ff @(posedge clk or posedge rst) begin
        if (rst) edgeDetect <= 0;
        else edgeDetect <= db;
    end

    assign btnDb = db & (~edgeDetect);

endmodule
