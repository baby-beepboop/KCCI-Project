module status_string_wrap;

    logic clk;
    logic reset;

    // status2uart inputs
    logic [13:0] st_count   = 14'd1234;
    logic        st_mode    = 1'b0; // up
    logic        st_runstop = 1'b1; // run
    logic        cmd_status;

    // status2uart outputs
    logic        status_valid;
    logic [7:0]  status_data;
    logic        status_ready;

    // loopback (optional, for contention test)
    logic        loopback_valid;
    logic [7:0]  loopback_data;
    logic        loopback_ready;

    // arbiter outputs
    logic        out_valid;
    logic [7:0]  out_data;

    // always ready sink
    logic out_ready = 1'b1;

    // clock
    always #5 clk = ~clk;

    initial begin
        clk = 0;
        reset = 1;
        #20 reset = 0;
    end

    // DUTs
    status2uart u_status2uart (
        .clk        (clk),
        .reset      (reset),
        .st_count   (st_count),
        .st_mode    (st_mode),
        .st_runstop (st_runstop),
        .cmd_status (cmd_status),
        .tx_ready   (status_ready),
        .tx_valid   (status_valid),
        .status_data(status_data)
    );

    tx_arbiter u_tx_arbiter (
        .out_ready      (out_ready),
        .loopback_valid (loopback_valid),
        .loopback_data  (loopback_data),
        .loopback_ready (loopback_ready),
        .status_valid   (status_valid),
        .status_data    (status_data),
        .status_ready   (status_ready),
        .out_valid      (out_valid),
        .out_data       (out_data)
    );

endmodule
