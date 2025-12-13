module controller(
    input clk, rst,

    input runStop, clear, mode,

    output reg [3:0] sFlag
    );

    typedef enum logic [1:0] {IDLE, UP, DOWN, PAUSE} state_t;
    state_t cState, nState;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) cState <= IDLE;
        else cState <= nState;
    end

    always_comb begin
        nState = cState;

        case (cState)
            IDLE: begin
                if (runStop) nState = UP;    // runStop = Run
                else if (mode) nState = DOWN;
            end
            UP: begin
                if (runStop)    nState = PAUSE;    // runStop = Stop
                else if (clear) nState = IDLE;
                else if (mode)  nState = DOWN;
            end
            DOWN: begin
                if (runStop)    nState = PAUSE;    // runStop = Stop
                else if (clear) nState = IDLE;
                else if (mode)  nState = UP;
            end
            PAUSE: begin
                if (runStop) begin                                  // runStop = Run
                    if (sFlag[2:1] == 2'b01)      nState = UP;
                    else if (sFlag[2:1] == 2'b10) nState = DOWN;
                end
                else if (clear) nState = IDLE;
                else if (mode) begin
                    if (sFlag[2:1] == 2'b01)      nState = DOWN;
                    else if (sFlag[2:1] == 2'b10) nState = UP;
                end
            end
            default: nState = IDLE;
        endcase
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            sFlag <= 0;
        end
        else begin
            case (cState)
                IDLE: sFlag <= 4'b0001;
                UP:   sFlag <= 4'b0010;
                DOWN: sFlag <= 4'b0100;
                PAUSE: begin
                    sFlag[0] <= 1'b0;
                    sFlag[3] <= 1'b1;
                end
            endcase
        end
    end

endmodule
