module cmdCtrl(
    input clk, rst,

    input       rxDone,
    input [7:0] rxData,

    output reg        rtcTxReq,    // txFormatter 요청 신호
    output reg [15:0] led
    );

    localparam QUEUE_SIZE = 64;
    localparam POINTER_WIDTH = 6;

    reg [7:0] queue [0:QUEUE_SIZE-1];
    reg [POINTER_WIDTH-1:0] rear = 0;
    reg [POINTER_WIDTH-1:0] front = 0;

    wire full = ((rear + 1) % QUEUE_SIZE == front);

    reg enter;

    localparam [1:0] RTC_SHOW=0, INVALID_CMD=4;
    reg [1:0] mode;

    reg [7:0] c0, c1, c2, c3, c4, c5, c6, c7, c8, c9;
    reg found;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rear <= 0;
        end

        else if (rxDone) begin
            queue[rear] <= rxData;
            rear <= (rear + 1) % QUEUE_SIZE;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) enter <= 0;
        else enter <= rxDone && ((rxData == "\r") || (rxData == "\n"));
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mode <= INVALID_CMD;
            front <= 0;
            rtcTxReq <= 0;
        end

        else if (enter) begin
            rtcTxReq <= 1'b0;

            c0 = queue[front];
            c1 = queue[(front + 1) % QUEUE_SIZE];
            c2 = queue[(front + 2) % QUEUE_SIZE];
            c3 = queue[(front + 3) % QUEUE_SIZE];
            c4 = queue[(front + 4) % QUEUE_SIZE];
            c5 = queue[(front + 5) % QUEUE_SIZE];
            c6 = queue[(front + 6) % QUEUE_SIZE];
            c7 = queue[(front + 7) % QUEUE_SIZE];
            c8 = queue[(front + 8) % QUEUE_SIZE];
            c9 = queue[(front + 9) % QUEUE_SIZE];

            found <= 1'b0;

            // rtc show
            if (c0 == "r" && c1 == "t" && c2 == "c" && c3 == " " &&
                c4 == "s" && c5 == "h" && c6 == "o" && c7 == "w") begin
                mode <= RTC_SHOW;
                found <= 1'b1;
                rtcTxReq <= 1'b1;
            end

            if (!found) begin
                mode <= INVALID_CMD;
            end

            front <= rear;
        end
    end

    // for Debug
    always @(*) begin
        led[15:1] = 14'h0000;
        case(mode)
            RTC_SHOW: led[1] = 1'b1;
            INVALID_CMD: led[15] = 1'b1;
            default: led[15:1] = 14'h0000;
        endcase
    end

    always @(posedge clk or posedge rst) begin
        if (rst) led[0] <= 1'b0;
        else begin
            if (rxDone) led[0] <= ~led[0];
        end
    end

endmodule
