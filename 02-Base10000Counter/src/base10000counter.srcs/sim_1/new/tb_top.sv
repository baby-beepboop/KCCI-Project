`timescale 1ns / 1ps

module tb_top;
    localparam CLKS_PER_BIT = 651 * 10;    // = (1/(BPS*16)) * CLK_PERIOD

    reg clk, rst;

    reg runStop, clear, mode;
    logic [3:0] an;
    logic [6:0] seg;

    reg rxIn;
    logic txOut;

    top dut (.clk(clk), .rst(rst), .runStop(runStop), .clear(clear), .mode(mode), .an(an), .seg(seg), .rxIn(rxIn), .txOut(txOut));

    initial clk = 0;
    always #5 clk = ~clk;

    bit [7:0] cmd;

    task pcTx();
        rxIn = 1'b0;
        $display("[%0t] Sending start bit", $time);
        repeat(16) #(CLKS_PER_BIT);

        for (int i=0; i<8; i++) begin
            rxIn = cmd[i];
            $display("[%0t] Sending data bit[%0d] = %0d", $time, i, rxIn);
            repeat(16) #(CLKS_PER_BIT);
        end

        rxIn = 1'b1;
        $display("[%0t] Sending stop bit", $time);
        repeat(16) #(CLKS_PER_BIT);
    endtask

    initial begin
        $display("==========================================================================================================");
        $display("                                        TOP LEVEL Simulation Start                                        ");
        $display("==========================================================================================================");

        rst = 1;
        runStop = 0; clear = 0; mode = 0;
        rxIn = 1;
        #100 rst = 0;
        $display("[%0t] Reset released", $time);

        #100 cmd = "R";
        $display("[%0t] Sending command \"R\" (0x%0h = %b)", $time, cmd, cmd);
        pcTx();
//        cmd = 0;

        for (int i=0; i<8; i++) begin
            @(dut.txDone);
            $display("[%0t] Received message 0x%0h", $time, (dut.u_uart.u_uartTx.dataReg));
            #(CLKS_PER_BIT);
        end

        #100 cmd = "C";
        $display("[%0t] Sending command \"C\" (0x%0h = %b)", $time, cmd, cmd);
        pcTx();
//        cmd = 0;

        for (int i=0; i<8; i++) begin
            @(dut.txDone);
            $display("[%0t] Received message 0x%0h", $time, (dut.u_uart.u_uartTx.dataReg));
            #(CLKS_PER_BIT);
        end

        #100 cmd = "M";
        $display("[%0t] Sending command \"M\" (0x%0h = %b)", $time, cmd, cmd);
        pcTx();
//        cmd = 0;

        for (int i=0; i<8; i++) begin
            @(dut.txDone);
            $display("[%0t] Received message 0x%0h", $time, (dut.u_uart.u_uartTx.dataReg));
            #(CLKS_PER_BIT);
        end

        $stop;
    end

endmodule
