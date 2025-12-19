// tb_uartRx v1.0.0: UART Rx 검증 (UVM)
// 검증 시나리오: 랜덤 데이터 생성 (generator) -> baud tick이 16번 발생할 때마다 데이터 입력 (drive)
//              -> baud tick 카운터가 7일 때 데이터 샘플링 (monitor) -> done 신호가 high일 때 출력과 입력 비교 (scoreboard)
`timescale 1ns / 1ps

localparam CLKS_PER_BIT = 651 * 10;

interface itf;
    reg clk, rst;

    logic       baudTick;
    logic [3:0] baudTickCnt;

    reg dataIn;

    logic       done;
    logic [7:0] dataOut;
endinterface

class transaction;
    rand bit dataIn;
    bit [7:0] referData;

    logic done;
    logic [7:0] dataOut;
endclass

class generator;
    virtual itf itf;
    transaction trans;
    mailbox #(transaction) gen2drv;
    event txReq;
    event scb2gen;

    function new(virtual itf itf, mailbox #(transaction) gen2drv, event txReq, event scb2gen);
        this.itf = itf;
        this.gen2drv = gen2drv;
        this.txReq = txReq;
        this.scb2gen = scb2gen;
    endfunction

    task run(int cnt);
        repeat(cnt) begin
            trans = new();

            wait(itf.baudTickCnt == 0);
            trans.dataIn = 1'b0;
            $display("[%0t] [GEN] Start bit", $time);
            gen2drv.put(trans);
            @(txReq);

            for (int i=0; i<8; i++) begin
                trans.randomize();
                $display("[%0t] [GEN] Data bit[%0d] = %0d", $time, i, trans.dataIn);
                gen2drv.put(trans);
                @(txReq);
            end

            trans.dataIn = 1'b1;
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

            if (trans.dataOut == trans.referData) begin
                passCnt++;
                $display("[%0t] [SCB] PASS %0d: dataOut matches dataIn: 0x%0h = %0b", $time, passCnt, trans.dataOut, trans.referData);
            end
            else begin
                failCnt++;
                $display("[%0t] [SCB] FAIL %0d: dataOut 0x%0h but dataIn %0b", $time, failCnt, trans.dataOut, trans.referData);
            end

            -> scb2gen;
        end
    endtask
endclass

class driver;
    virtual itf itf;
    transaction trans;
    mailbox #(transaction) gen2drv;
    event txReq;
    event drv2mon;

    function new(virtual itf itf, mailbox #(transaction) gen2drv, event txReq, event drv2mon);
        this.itf = itf;
        this.gen2drv = gen2drv;
        this.txReq = txReq;
        this.drv2mon = drv2mon;
    endfunction

    task reset;
        itf.rst = 1;
        itf.dataIn = 1;
        @(posedge itf.clk);
        itf.rst = 0;
        $display("[%0t] Reset released", $time);
    endtask

    task run;
        forever begin
            #(CLKS_PER_BIT);
            wait(itf.baudTickCnt == 0);
            gen2drv.get(trans);
            itf.dataIn = trans.dataIn;
            $display("[%0t] [DRV] Start bit %0d", $time, trans.dataIn);
            repeat(8) #(CLKS_PER_BIT);
            -> drv2mon;
            -> txReq;
            repeat(8) #(CLKS_PER_BIT);

            for (int i=0; i<8; i++) begin
                gen2drv.get(trans);
                itf.dataIn = trans.dataIn;
                $display("[%0t] [DRV] Data bit[%0d] = %0d", $time, i, trans.dataIn);
                repeat(8) #(CLKS_PER_BIT);
                -> drv2mon;
                -> txReq;
                repeat(8) #(CLKS_PER_BIT);
            end

            gen2drv.get(trans);
            itf.dataIn = trans.dataIn;
            $display("[%0t] [DRV] Stop bit %0d", $time, trans.dataIn);
            repeat(8) #(CLKS_PER_BIT);
            -> drv2mon;
            -> txReq;
            repeat(8) #(CLKS_PER_BIT);
        end
    endtask
endclass

class monitor;
    virtual itf itf;
    transaction trans;
    event drv2mon;
    mailbox #(transaction) mon2scb;

    bit [7:0] dataReg;

    function new(virtual itf itf, event drv2mon, mailbox #(transaction) mon2scb);
        this.itf = itf;
        this.drv2mon = drv2mon;
        this.mon2scb = mon2scb;
    endfunction

    task run;
        forever begin
            @(drv2mon);
            $display("[%0t] [MON] Start bit %0d", $time, itf.dataIn);

            for (int i=0; i<8; i++) begin
                @(drv2mon);
                dataReg[i] = itf.dataIn;
                $display("[%0t] [MON] Data bit[%0d] = %0d", $time, i, itf.dataIn);
            end
            $display("[%0t] [MON] dataIn = %0b = 0x%0h", $time, dataReg, dataReg);

            @(itf.done);
            trans = new();
            trans.referData = dataReg;
            trans.done = itf.done;
            trans.dataOut = itf.dataOut;
            mon2scb.put(trans);
            $display("[%0t] [MON] dataOut = 0x%0h", $time, itf.dataOut);
            
            @(drv2mon);
            $display("[%0t] [MON] Stop bit %0d", $time, itf.dataIn);
        end
    endtask
endclass

class environment;
    transaction trans;
    generator gen;
    driver drv;
    mailbox #(transaction) gen2drv;
    event txReq;
    event drv2mon;
    scoreboard scb;
    monitor mon;
    mailbox #(transaction) mon2scb;
    event scb2gen;

    function new(virtual itf itf);
        gen2drv = new();
        gen = new(itf, gen2drv, txReq, scb2gen);
        drv = new(itf, gen2drv, txReq, drv2mon);
        mon2scb = new();
        scb = new(mon2scb, scb2gen);
        mon = new(itf, drv2mon, mon2scb);
    endfunction

    task run;
        drv.reset();

        fork
            gen.run(100);
            drv.run();
            mon.run();
            scb.run();
        join_any

        report();
        $display("[%0t] Simulation finished", $time);
        $finish;
    endtask

    task report;
        $display("                                            Final Report                                            ");
        $display("----------------------------------------------------------------------------------------------------");
        $display("Total Test: %0d", scb.totalCnt);
        $display("      Pass: %0d", scb.passCnt);
        $display("      Fail: %0d", scb.failCnt);
    endtask
endclass

module tb_uartRx;
    itf itf();
    baudTickGen #(.BPS(9600)) u_baudTickGen (.clk(itf.clk), .rst(itf.rst), .tick(itf.baudTick), .tickCnt(itf.baudTickCnt));
    uart_rx #(.BPS(9600)) uut (
        .clk(itf.clk), .rst(itf.rst),
        .baudTick(itf.baudTick), .baudTickCnt(itf.baudTickCnt),
        .dataIn(itf.dataIn),
        .done(itf.done), .dataOut(itf.dataOut));

    initial itf.clk = 0;
    always #5 itf.clk = ~itf.clk;

    environment env;

    initial begin
        $display("====================================================================================================");
        $display("                                      UART Rx Simulation Start                                      ");
        $display("====================================================================================================");
    
        env = new(itf);
        env.run();
    end

endmodule
