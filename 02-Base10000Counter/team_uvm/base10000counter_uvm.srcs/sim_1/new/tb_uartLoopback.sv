// tb_uartLoopback v1.0.0: UART-FIFO loopback 구조 검증
`timescale 1ns / 1ps

import pkg_uartRx::*;

interface itf_loopback;
    logic txOut;

    logic [7:0] wdata, rx2txData, rdata;
    logic txBusy, txDone;
    logic fifoRxEmpty, fifoTxEmpty, fifoTxFull;
endinterface

class transaction_loopback;
    logic [7:0] rxReg, txReg;

    logic [7:0] wdata, rx2txData, rdata;
endclass

class scoreboard_loopback;
    transaction_loopback trans;
    mailbox #(transaction_loopback) mon2scb;
    event scb2gen;

    int totalCnt, passCnt, failCnt;

    function new(mailbox #(transaction_loopback) mon2scb, event scb2gen);
        this.mon2scb = mon2scb;
        this.scb2gen = scb2gen;
    endfunction

    task run;
        forever begin
            mon2scb.get(trans);
            totalCnt++;

            if (trans.rxReg == trans.txReg) begin
                passCnt++;
                $display("[%0t] [SCB] PASS %0d: txOut matches rxIn: 0x%0h", $time, passCnt, trans.txReg, trans.rxReg);
            end
            else begin
                failCnt++;
                $display("[%0t] [SCB] FAIL %0d: txOut 0x%0h but rxIn %0h", $time, failCnt, trans.txReg, trans.rxReg);
            end

            -> scb2gen;
        end
    endtask
endclass

class monitor_loopback;
    virtual itf_uartRx itf_uartRx;
    virtual itf_loopback itf;
    transaction_loopback trans;
    event drv2mon;
    mailbox #(transaction_loopback) mon2scb;

    bit [7:0] inReg, outReg;

    function new(virtual itf_uartRx itf_uartRx, virtual itf_loopback itf,
                 event drv2mon, mailbox #(transaction_loopback) mon2scb);
        this.itf_uartRx = itf_uartRx;
        this.itf = itf;
        this.drv2mon = drv2mon;
        this.mon2scb = mon2scb;
    endfunction

    task run;
        forever begin
            trans = new();

            @(drv2mon);
            $display("[%0t] [MON] Rx: Start bit %0d", $time, itf_uartRx.rxIn);

            for (int i=0; i<8; i++) begin
                @(drv2mon);
                inReg[i] = itf_uartRx.rxIn;
                $display("[%0t] [MON] Rx: Data bit[%0d] = %0d", $time, i, itf_uartRx.rxIn);
            end

            @(itf_uartRx.rxDone);
            trans.rxReg = inReg;
            $display("[%0t] [MON] rxIn = %0b = 0x%0h", $time, trans.rxReg, trans.rxReg);

            trans.wdata = itf.wdata;
            @(posedge itf_uartRx.clk) trans.rx2txData = itf.rx2txData;
            @(posedge itf_uartRx.clk) trans.rdata = itf.rdata;
            $display("[%0t] [MON] wdata = 0x%0h, rx2txData = 0x%0h, rdata = 0x%0h", $time, trans.wdata, trans.rx2txData, trans.rdata);

            @(drv2mon);
            $display("[%0t] [MON] Rx: Stop bit %0d", $time, itf_uartRx.rxIn);
            
            repeat(16) #(CLKS_PER_BIT);
            $display("[%0t] [MON] Tx: Start bit %0d", $time, itf.txOut);

            for (int i=0; i<8; i++) begin
                repeat(16) #(CLKS_PER_BIT);
                outReg[i] = itf.txOut;
                $display("[%0t] [MON] Tx: Data bit[%0d] %0d", $time, i, itf.txOut);
            end
            trans.txReg = outReg;

            repeat(16) #(CLKS_PER_BIT);
            $display("[%0t] [MON] Tx: Stop bit %0d", $time, itf.txOut);

            $display("[%0t] [MON] txOut = %0b = 0x%0h", $time, trans.txReg, trans.txReg);

            mon2scb.put(trans);
        end
    endtask
endclass

class environment_loopback;
    virtual itf_uartRx itf_uartRx;
    transaction_uartRx trans_uartRx;
    generator_uartRx gen_uartRx;
    driver_uartRx drv_uartRx;
    mailbox #(transaction_uartRx) gen2drv;
    event txReq;
    
    transaction_loopback trans;
    scoreboard_loopback scb;
    monitor_loopback mon;
    mailbox #(transaction_loopback) mon2scb;
    event scb2gen, drv2mon;

    function new(virtual itf_uartRx itf_uartRx, virtual itf_loopback itf);
        this.itf_uartRx = itf_uartRx;
        gen2drv = new();
        gen_uartRx = new(itf_uartRx, gen2drv, txReq, scb2gen);
        drv_uartRx = new(itf_uartRx, gen2drv, txReq, drv2mon);
        mon2scb = new();
        mon = new(itf_uartRx, itf, drv2mon, mon2scb);
        scb = new(mon2scb, scb2gen);
    endfunction

    task run;
        drv_uartRx.reset();
        
        fork
            gen_uartRx.run(10);
            drv_uartRx.run();
            mon.run();
            scb.run();
        join_any

        report();
        $finish;
    endtask

    task report;
        $display("                                            Final Report                                             ");
        $display("-----------------------------------------------------------------------------------------------------");
        $display("Total Test: %0d", scb.totalCnt);
        $display("      Pass: %0d", scb.passCnt);
        $display("      Fail: %0d", scb.failCnt);
    endtask
endclass

module tb_uartLoopback;
    itf_uartRx itf_uartRx();
    itf_loopback itf();

    baudTickGen #(.BPS(9600)) u_baudTickGen (
        .clk(itf_uartRx.clk), .rst(itf_uartRx.rst),
        .tick(itf_uartRx.baudTick), .tickCnt(itf_uartRx.baudTickCnt));
    
    uart_rx #(.BPS(9600)) u_uartRx (
        .clk(itf_uartRx.clk), .rst(itf_uartRx.rst),
        .baudTick(itf_uartRx.baudTick), .baudTickCnt(itf_uartRx.baudTickCnt),
        .dataIn(itf_uartRx.rxIn),
        .dataOut(itf.wdata), .done(itf_uartRx.rxDone));

    fifo_rx u_fifoRx (
        .clk(itf_uartRx.clk), .reset(itf_uartRx.rst),
        .wr(itf_uartRx.rxDone), .wdata(itf.wdata),
        .rd(~(itf.fifoTxFull)), .rdata(itf.rx2txData),
        .empty(itf.fifoRxEmpty), .full());

    fifo_tx u_fifoTx (
        .clk(itf_uartRx.clk), .reset(itf_uartRx.rst),
        .wr(~(itf.fifoRxEmpty)), .wdata(itf.rx2txData),
        .rd(~(itf.txBusy)), .rdata(itf.rdata),
        .empty(itf.fifoTxEmpty), .full(itf.fifoTxFull));

    uart_tx #(.BPS(9600)) u_uartTx (
        .clk(itf_uartRx.clk), .rst(itf_uartRx.rst),
        .baudTick(itf_uartRx.baudTick), .baudTickCnt(itf_uartRx.baudTickCnt),
        .en(~(itf.fifoTxEmpty)), .dataIn(itf.rdata),
        .dataOut(itf.txOut), .busy(itf.txBusy), .done(itf.txDone));

    initial itf_uartRx.clk = 0;
    always #5 itf_uartRx.clk = ~itf_uartRx.clk;

    environment_loopback env;

    initial begin
        $display("====================================================================================================");
        $display("                                   UART Loopback Simulation Start                                   ");
        $display("====================================================================================================");

        env = new(itf_uartRx, itf);
        env.run();
    end

endmodule
