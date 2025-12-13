module fndController(
    input clk, rst,

    input [13:0] cnt,
    
    output [3:0] an,
    output [6:0] seg
    );

    logic tick400;

    tickGen #(.TICK_FREQ(400)) u_tick400Gen (.clk(clk), .rst(rst), .tick(tick400));

    fndCtrl u_fndCtrl (.clk(clk), .rst(rst), .tick(tick400), .segData(cnt), .an(an), .seg(seg));

endmodule
