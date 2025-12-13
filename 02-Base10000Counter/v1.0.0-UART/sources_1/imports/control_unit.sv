module control_unit(
    input clk, rst,

    input runStop, clear, mode,

    output [3:0] sFlag
    );

    controller u_controller (.clk(clk), .rst(rst), .runStop(runStop), .clear(clear), .mode(mode), .sFlag(sFlag));

endmodule
