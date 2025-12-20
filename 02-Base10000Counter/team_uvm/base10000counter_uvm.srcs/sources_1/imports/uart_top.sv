`timescale 1ns / 1ps

module uart_top (
    input        clk,
    input        reset,
    input        rx,
    input        tx_valid,
    input  [7:0] tx_data,
    input        rx_ready,
    output       rx_valid,
    output [7:0] rx_data,
    output       tx_ready,
    output       tx
);

    localparam BPS_VAL = 9600;

    wire       baudTick;
    wire [3:0] baudTickCnt;
    wire       rx_done;
    wire [7:0] rx_byte;

    uart_rx #(
        .BPS(BPS_VAL)
    ) u_uartRx (
        .clk        (clk),
        .rst        (reset),
        .baudTick   (baudTick),
        .baudTickCnt(baudTickCnt),
        .dataIn     (rx),
        .done       (rx_done),
        .dataOut    (rx_byte)
    );

    wire rx_push = rx_done;
    wire rx_cmd_empty;
    wire [7:0] rx_cmd_rdata;

    fifo_rx u_rx_cmd_fifo (
        .clk  (clk),
        .reset(reset),
        .wr   (rx_push),
        .rd   (rx_valid && rx_ready),
        .wdata(rx_byte),
        .rdata(rx_cmd_rdata),
        .full (),
        .empty(rx_cmd_empty)
    );

    assign rx_valid = ~rx_cmd_empty;
    assign rx_data  = rx_cmd_rdata;

    wire rx_echo_empty;
    wire [7:0] rx_echo_rdata;
    wire rx_echo_rd;

    fifo_rx u_rx_echo_fifo (
        .clk  (clk),
        .reset(reset),
        .wr   (rx_push),
        .rd   (rx_echo_rd),
        .wdata(rx_byte),
        .rdata(rx_echo_rdata),
        .full (),
        .empty(rx_echo_empty)
    );

    wire       tx_fifo_full;
    wire       tx_fifo_empty;
    wire [7:0] tx_fifo_rdata;
    wire       tx_fifo_wr;
    wire [7:0] tx_fifo_wdata;
    wire       tx_fifo_rd;

    fifo_tx u_fifo_tx (
        .clk  (clk),
        .reset(reset),
        .wr   (tx_fifo_wr),
        .rd   (tx_fifo_rd),
        .wdata(tx_fifo_wdata),
        .rdata(tx_fifo_rdata),
        .full (tx_fifo_full),
        .empty(tx_fifo_empty)
    );

    wire out_ready = ~tx_fifo_full;
    wire out_valid;
    wire [7:0] out_data;
    wire echo_ready;
    wire status_ready_i;

    tx_arbiter u_tx_arbiter (
        .clk            (clk),
        .reset      (reset),
        .out_ready     (out_ready),
        .loopback_valid(~rx_echo_empty),
        .loopback_data (rx_echo_rdata),
        .status_valid  (tx_valid),
        .status_data   (tx_data),
        .loopback_ready(echo_ready),
        .status_ready  (status_ready_i),
        .out_valid     (out_valid),
        .out_data      (out_data)
    );

    assign tx_ready      = status_ready_i;
    assign tx_fifo_wr    = out_valid && out_ready;
    assign tx_fifo_wdata = out_data;
    assign rx_echo_rd    = echo_ready;

    reg  [7:0] tx_hold;
    reg        tx_start;
    wire       tx_busy;
    wire       can_start_tx = ~tx_busy && ~tx_fifo_empty;

    assign tx_fifo_rd = tx_start;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            tx_start <= 1'b0;
            tx_hold  <= 8'h00;
        end else begin
            tx_start <= 1'b0;
            if (can_start_tx) begin
                tx_hold  <= tx_fifo_rdata;
                tx_start <= 1'b1;
            end
        end
    end

    uart_tx #(
        .BPS(BPS_VAL)
    ) u_uartTx (
        .clk        (clk),
        .rst        (reset),
        .baudTick   (baudTick),
        .baudTickCnt(baudTickCnt),
        .en         (tx_start),
        .dataIn     (tx_hold),
        .busy       (tx_busy),
        .done       (),
        .dataOut    (tx)
    );

    baudTickGen #(
        .BPS(BPS_VAL)
    ) u_baudTickGen (
        .clk    (clk),
        .rst    (reset),
        .tick   (baudTick),
        .tickCnt(baudTickCnt)
    );

endmodule


module tx_arbiter (
    input              clk,
    input              reset,

    input              out_ready,

    input              loopback_valid,
    input        [7:0] loopback_data,
    output logic       loopback_ready,

    input              status_valid,
    input        [7:0] status_data,
    output logic       status_ready,

    output logic       out_valid,
    output logic [7:0] out_data
);

    // 0: loopback, 1: status
    logic last_grant;

    logic grant_loopback;
    logic grant_status;

    // ---------------------------
    // 1) Grant 결정
    // ---------------------------
    always_comb begin
        grant_loopback = 1'b0;
        grant_status   = 1'b0;

        if (out_ready) begin
            case ({loopback_valid, status_valid})
                2'b10: grant_loopback = 1'b1;
                2'b01: grant_status   = 1'b1;
                2'b11: begin
                    // round-robin
                    if (last_grant == 1'b0)
                        grant_status = 1'b1;
                    else
                        grant_loopback = 1'b1;
                end
                default: ;
            endcase
        end
    end

    // ---------------------------
    // 2) Output
    // ---------------------------
    always_comb begin
        out_valid      = grant_loopback | grant_status;
        out_data       = grant_loopback ? loopback_data : status_data;
        loopback_ready = grant_loopback;
        status_ready   = grant_status;
    end

    // ---------------------------
    // 3) State update
    // ---------------------------
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            last_grant <= 1'b0; // reset 후 loopback 우선
        end else if (out_ready && out_valid) begin
            if (grant_loopback)
                last_grant <= 1'b0;
            else if (grant_status)
                last_grant <= 1'b1;
        end
    end

endmodule
