// txFormatter v1.0.0: RTC 데이터를 "YY. MM. DD. (DOW) HH:MM:SS KST" 형태로 변환 및 전송
module txFormatter(
    input clk, rst,

    // RTC 입력 데이터
    input       trig,
    input [7:0] secData, minData, hrsData, dateData, monData, dayData, yrData,

    // UART Tx Core Handshake
    input busy, done,

    // UART Tx Core 출력
    output reg       txEn,
    output reg [7:0] data
    );

    localparam [5:0] IDLE=0, TX_DONE=33;
    localparam [5:0] TX_YR_T=1, TX_YR_U=2, TX_DOT1=3, TX_SP1=4,                                              // YY.
                     TX_MON_T=5, TX_MON_U=6, TX_DOT2=7, TX_SP2=8,                                            // MM.
                     TX_DATE_T=9, TX_DATE_U=10, TX_DOT3=11, TX_SP3=12,                                       // DD.
                     TX_PAREN_OP=13, TX_DOW_B1=14, TX_DOW_B2=15, TX_DOW_B3=16, TX_PAREN_CL=17, TX_SP4=18,    // (DOW)
                     TX_HRS_T=19, TX_HRS_U=20, TX_COL1=21,                                                   // HH:
                     TX_MIN_T=22, TX_MIN_U=23, TX_COL2=24,                                                   // MM:
                     TX_SEC_T=25, TX_SEC_U=26, TX_SP5=27,                                                    // SS
                     TX_K=28, TX_S=29, TX_T=30,                                                              // KST
                     TX_CR=31, TX_LF=32;
    reg [5:0] cState, nState;

    reg trigDelay;
    reg en;

    reg [7:0] dowChar1, dowChar2, dowChar3;

    // 트리거 신호 1 clock 펄스 변환
    always @(posedge clk or posedge rst) begin
        if (rst) trigDelay <= 0;
        else trigDelay <= trig;
    end

    wire trigEdge = trig && !trigDelay;

    // FSM 상태 전이
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cState <= IDLE;
            en <= 0;
        end
        else begin
            cState <= nState;
            en <= 1'b0;

            if (trigEdge && !busy) en <= 1'b1;
            else if ((cState == TX_DONE) && !busy) en <= 1'b0;
        end
    end

    always @(*) begin
        nState = cState;

        case (cState)
            IDLE: if (en) nState = TX_YR_T;

            TX_YR_T: if (done) nState = TX_YR_U;
            TX_YR_U: if (done) nState = TX_DOT1;
            TX_DOT1: if (done) nState = TX_SP1;
            TX_SP1:  if (done) nState = TX_MON_T;

            TX_MON_T: if (done) nState = TX_MON_U;
            TX_MON_U: if (done) nState = TX_DOT2;
            TX_DOT2:  if (done) nState = TX_SP2;
            TX_SP2:   if (done) nState = TX_DATE_T;

            TX_DATE_T: if (done) nState = TX_DATE_U;
            TX_DATE_U: if (done) nState = TX_DOT3;
            TX_DOT3:   if (done) nState = TX_SP3;
            TX_SP3:    if (done) nState = TX_PAREN_OP;

            TX_PAREN_OP: if (done) nState = TX_DOW_B1;
            TX_DOW_B1:   if (done) nState = TX_DOW_B2;
            TX_DOW_B2:   if (done) nState = TX_DOW_B3;
            TX_DOW_B3:   if (done) nState = TX_PAREN_CL;
            TX_PAREN_CL: if (done) nState = TX_SP4;
            TX_SP4:      if (done) nState = TX_HRS_T;

            TX_HRS_T: if (done) nState = TX_HRS_U;
            TX_HRS_U: if (done) nState = TX_COL1;
            TX_COL1:  if (done) nState = TX_MIN_T;

            TX_MIN_T: if (done) nState = TX_MIN_U;
            TX_MIN_U: if (done) nState = TX_COL2;
            TX_COL2:  if (done) nState = TX_SEC_T;

            TX_SEC_T: if (done) nState = TX_SEC_U;
            TX_SEC_U: if (done) nState = TX_SP5;
            TX_SP5:   if (done) nState = TX_K;

            TX_K: if (done) nState = TX_S;
            TX_S: if (done) nState = TX_T;
            TX_T: if (done) nState = TX_CR;

            TX_CR: if (done) nState = TX_LF;
            TX_LF: if (done) nState = TX_DONE;

            TX_DONE: if (!busy) nState = IDLE;
            default: nState = IDLE;
        endcase
    end

    // BCD to ASCII
    function [7:0] bcd2ascii;
        input [3:0] bcdNibble;
        begin
            bcd2ascii = bcdNibble + 8'h30;
        end
    endfunction

    // Day of Week UTF-8 매핑
    // dayData (1=SUN, 7=SAT)에 따라 3글자 ASCII 약자
    always @(*) begin
        dowChar1 = 8'h53; dowChar2 = 8'h55; dowChar3 = 8'h4E;

        case (dayData[2:0])
            3'd1: begin    // SUN
                dowChar1 = 8'h53; dowChar2 = 8'h55; dowChar3 = 8'h4E;
            end
            3'd2: begin    // MON
                dowChar1 = 8'h4D; dowChar2 = 8'h4F; dowChar3 = 8'h4E;
            end
            3'd3: begin    // TUE
                dowChar1 = 8'h54; dowChar2 = 8'h55; dowChar3 = 8'h45;
            end
            3'd4: begin    // WED
                dowChar1 = 8'h57; dowChar2 = 8'h45; dowChar3 = 8'h44;
            end
            3'd5: begin    // THU
                dowChar1 = 8'h54; dowChar2 = 8'h48; dowChar3 = 8'h55;
            end
            3'd6: begin    // FRI
                dowChar1 = 8'h46; dowChar2 = 8'h52; dowChar3 = 8'h49;
            end
            3'd7: begin    // SAT
                dowChar1 = 8'h53; dowChar2 = 8'h41; dowChar3 = 8'h54;
            end
        endcase
    end

    // 출력 신호
    always @(*) begin
        txEn = 0;
        data = 0;

        if ((cState >= TX_YR_T) && (cState <= TX_LF)) begin
            txEn = 1'b1;
        end

        case (cState)
            TX_YR_T: data = bcd2ascii(yrData[7:4]);
            TX_YR_U: data = bcd2ascii(yrData[3:0]);
            TX_DOT1: data = 8'h2E;    // "."
            TX_SP1:  data = 8'h20;    // SP

            TX_MON_T: data = bcd2ascii(monData[7:4]);
            TX_MON_U: data = bcd2ascii(monData[3:0]);
            TX_DOT2:  data = 8'h2E;    // "."
            TX_SP2:   data = 8'h20;    // SP

            TX_DATE_T: data = bcd2ascii(dateData[7:4]);
            TX_DATE_U: data = bcd2ascii(dateData[3:0]);
            TX_DOT3:   data = 8'h2E;    // "."
            TX_SP3:    data = 8'h20;    // SP

            TX_PAREN_OP: data = 8'h28;    // "("
            TX_DOW_B1:   data = dowChar1;
            TX_DOW_B2:   data = dowChar2;
            TX_DOW_B3:   data = dowChar3;
            TX_PAREN_CL: data = 8'h29;    // ")"
            TX_SP4:      data = 8'h20;    // SP

            TX_HRS_T: data = bcd2ascii(hrsData[7:4]);
            TX_HRS_U: data = bcd2ascii(hrsData[3:0]);
            TX_COL1:  data = 8'h3A;    // ":"

            TX_MIN_T: data = bcd2ascii(minData[7:4]);
            TX_MIN_U: data = bcd2ascii(minData[3:0]);
            TX_COL2:  data = 8'h3A;    // ":"

            TX_SEC_T: data = bcd2ascii(secData[7:4]);
            TX_SEC_U: data = bcd2ascii(secData[3:0]);
            TX_SP5:   data = 8'h20;    // SP

            TX_K: data = 8'h4B;    // "K"
            TX_S: data = 8'h53;    // "S"
            TX_T: data = 8'h54;    // "T"

            TX_CR: data = 8'h0D;    // CR
            TX_LF: data = 8'h0A;    // LF
        endcase
    end

endmodule
