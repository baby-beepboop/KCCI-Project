// tb_uartLoopback v1.0.0: UART-FIFO loopback 구조 검증
`timescale 1ns / 1ps

localparam CLKS_PER_BIT = 651 * 10;

interface itf;
    reg clk, rst;

    logic       baudTick;
    logic [3:0] baudTickCnt;

    reg rxIn;
    logic txOut;

    logic [7:0] wdata, rx2txData, rdata;
    logic rxDone, txBusy, txDone;
    logic fifoRxEmpty, fifoTxEmpty, fifoTxFull;
endinterface

class transaction;
    rand bit rxIn;

    logic [7:0] rxReg, txReg;

    logic [7:0] wdata, rx2txData, rdata;
endclass

class generator;
    virtual itf itf;
    transaction trans;
    mailbox #(transaction) gen2drv;
    event moreBit;
    event scb2gen;

    function new(virtual itf itf, mailbox #(transaction) gen2drv, event moreBit, event scb2gen);
        this.itf = itf;
        this.gen2drv = gen2drv;
        this.moreBit = moreBit;
        this.scb2gen = scb2gen;
    endfunction

    task run(int cnt);
        repeat(cnt) begin
            trans = new();

            wait(itf.baudTickCnt == 0);
            trans.rxIn = 1'b0;
            $display("[%0t] [GEN] Start bit", $time);
            gen2drv.put(trans);
            @(moreBit);

            for (int i=0; i<8; i++) begin
                trans.randomize();
                $display("[%0t] [GEN] Data bit[%0d] = %0d", $time, i, trans.rxIn);
                gen2drv.put(trans);
                @(moreBit);
            end

            trans.rxIn = 1'b1;
            $display("[%0t] [GEN] Stop bit", $time);
            gen2drv.put(trans);

            @(scb2gen);
            $display("----------------------------------------------------------------------------------------------------");
        end
    endtask
endclass

class scoreboard;
    transaction trans;
    mailbox #(transaction) mon2scb;
    event scb2gen;

    int totalCnt, passCnt, failCnt;

    function new(mailbox #(transaction) mon2scb, event scb2gen);
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

class driver;
    virtual itf itf;
    transaction trans;
    mailbox #(transaction) gen2drv;
    event moreBit;
    event drv2mon;

    function new(virtual itf itf, mailbox #(transaction) gen2drv, event moreBit, event drv2mon);
        this.itf = itf;
        this.gen2drv = gen2drv;
        this.moreBit = moreBit;
        this.drv2mon = drv2mon;
    endfunction

    task reset;
        itf.rst = 1;
        itf.rxIn = 1;
        @(posedge itf.clk);
        itf.rst = 0;
        $display("[%0t] Reset released", $time);
    endtask

    task run;
        forever begin
            #(CLKS_PER_BIT);
            wait(itf.baudTickCnt == 0);
            gen2drv.get(trans);
            itf.rxIn = trans.rxIn;
            $display("[%0t] [DRV] Start bit %0d", $time, trans.rxIn);
            repeat(8) #(CLKS_PER_BIT);
            -> drv2mon;
            -> moreBit;
            repeat(8) #(CLKS_PER_BIT);

            for (int i=0; i<8; i++) begin
                gen2drv.get(trans);
                itf.rxIn = trans.rxIn;
                $display("[%0t] [DRV] Data bit[%0d] = %0d", $time, i, trans.rxIn);
                repeat(8) #(CLKS_PER_BIT);
                -> drv2mon;
                -> moreBit;
                repeat(8) #(CLKS_PER_BIT);
            end

            gen2drv.get(trans);
            itf.rxIn = trans.rxIn;
            $display("[%0t] [DRV] Stop bit %0d", $time, trans.rxIn);
            repeat(8) #(CLKS_PER_BIT);
            -> drv2mon;
            -> moreBit;
            repeat(8) #(CLKS_PER_BIT);
        end
    endtask
endclass

class monitor;
    virtual itf itf;
    transaction trans;
    event drv2mon;
    mailbox #(transaction) mon2scb;

    bit [7:0] inReg, outReg;

    function new(virtual itf itf, event drv2mon, mailbox #(transaction) mon2scb);
        this.itf = itf;
        this.drv2mon = drv2mon;
        this.mon2scb = mon2scb;
    endfunction

    task run;
        forever begin
            trans = new();

            @(drv2mon);
            $display("[%0t] [MON] Rx: Start bit %0d", $time, itf.rxIn);

            for (int i=0; i<8; i++) begin
                @(drv2mon);
                inReg[i] = itf.rxIn;
                $display("[%0t] [MON] Rx: Data bit[%0d] = %0d", $time, i, itf.rxIn);
            end

            @(itf.rxDone);
            trans.rxReg = inReg;
            $display("[%0t] [MON] rxIn = %0b = 0x%0h", $time, trans.rxReg, trans.rxReg);

            trans.wdata = itf.wdata;
            @(posedge itf.clk) trans.rx2txData = itf.rx2txData;
            @(posedge itf.clk) trans.rdata = itf.rdata;
            $display("[%0t] [MON] wdata = 0x%0h, rx2txData = 0x%0h, rdata = 0x%0h", $time, trans.wdata, trans.rx2txData, trans.rdata);

            @(drv2mon);
            $display("[%0t] [MON] Rx: Stop bit %0d", $time, itf.rxIn);
            
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

class environment;
    transaction trans;
    generator gen;
    driver drv;
    mailbox #(transaction) gen2drv;
    scoreboard scb;
    monitor mon;
    mailbox #(transaction) mon2scb;
    event moreBit;
    event scb2gen, drv2mon;

    function new(virtual itf itf);
        gen2drv = new();
        gen = new(itf, gen2drv, moreBit, scb2gen);
        drv = new(itf, gen2drv, moreBit, drv2mon);
        mon2scb = new();
        mon = new(itf, drv2mon, mon2scb);
        scb = new(mon2scb, scb2gen);
    endfunction

    task run;
        drv.reset();

        fork
            gen.run(10);
            drv.run();
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
    itf itf();

    baudTickGen #(.BPS(9600)) u_baudTickGen (.clk(itf.clk), .rst(itf.rst), .tick(itf.baudTick), .tickCnt(itf.baudTickCnt));
    
    uart_rx #(.BPS(9600)) u_uartRx (
        .clk(itf.clk), .rst(itf.rst),
        .baudTick(itf.baudTick), .baudTickCnt(itf.baudTickCnt),
        .dataIn(itf.rxIn),
        .dataOut(itf.wdata), .done(itf.rxDone));

    fifo_rx u_fifoRx (
        .clk(itf.clk), .reset(itf.rst),
        .wr(itf.rxDone), .wdata(itf.wdata),
        .rd(~(itf.fifoTxFull)), .rdata(itf.rx2txData),
        .empty(itf.fifoRxEmpty), .full());

    fifo_tx u_fifoTx (
        .clk(itf.clk), .reset(itf.rst),
        .wr(~(itf.fifoRxEmpty)), .wdata(itf.rx2txData),
        .rd(~(itf.txBusy)), .rdata(itf.rdata),
        .empty(itf.fifoTxEmpty), .full(itf.fifoTxFull));

    uart_tx #(.BPS(9600)) u_uartTx (
        .clk(itf.clk), .rst(itf.rst),
        .baudTick(itf.baudTick), .baudTickCnt(itf.baudTickCnt),
        .en(~(itf.fifoTxEmpty)), .dataIn(itf.rdata),
        .dataOut(itf.txOut), .busy(itf.txBusy), .done(itf.txDone));

    initial itf.clk = 0;
    always #5 itf.clk = ~itf.clk;

    environment env;

    initial begin
        $display("====================================================================================================");
        $display("                                   UART Loopback Simulation Start                                   ");
        $display("====================================================================================================");

        env = new(itf);
        env.run();
    end

endmodule
