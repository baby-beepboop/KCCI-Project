// tb_uartRx v1.0.0: UART Rx 검증 (UVM)
// 검증 시나리오: 랜덤 데이터 생성 (generator) -> baud tick이 16번 발생할 때마다 데이터 입력 (drive)
//              -> baud tick 카운터가 7일 때 데이터 샘플링 (monitor) -> done 신호가 high일 때 출력과 입력 비교 (scoreboard)
`timescale 1ns / 1ps

import pkg_uartRx::*;

class scoreboard_uartRx;
    transaction_uartRx trans;
    mailbox #(transaction_uartRx) mon2scb;
    event scb2gen;

    int totalCnt, passCnt, failCnt;

    function new(mailbox #(transaction_uartRx) mon2scb, event scb2gen);
        this.mon2scb = mon2scb;
        this.scb2gen = scb2gen;
    endfunction

    task run;
        forever begin
            mon2scb.get(trans);
            totalCnt++;

            if (trans.rxOut == trans.referData) begin
                passCnt++;
                $display("[%0t] [SCB] PASS %0d: rxOut matches rxIn: 0x%0h = %0b", $time, passCnt, trans.rxOut, trans.referData);
            end
            else begin
                failCnt++;
                $display("[%0t] [SCB] FAIL %0d: rxOut 0x%0h but rxIn %0b", $time, failCnt, trans.rxOut, trans.referData);
            end

            -> scb2gen;
        end
    endtask
endclass

class monitor_uartRx;
    virtual itf_uartRx itf;
    transaction_uartRx trans;
    event drv2mon;
    mailbox #(transaction_uartRx) mon2scb;

    bit [7:0] dataReg;

    function new(virtual itf_uartRx itf, event drv2mon, mailbox #(transaction_uartRx) mon2scb);
        this.itf = itf;
        this.drv2mon = drv2mon;
        this.mon2scb = mon2scb;
    endfunction

    task run;
        forever begin
            @(drv2mon);
            $display("[%0t] [MON] Start bit %0d", $time, itf.rxIn);

            for (int i=0; i<8; i++) begin
                @(drv2mon);
                dataReg[i] = itf.rxIn;
                $display("[%0t] [MON] Data bit[%0d] = %0d", $time, i, itf.rxIn);
            end
            $display("[%0t] [MON] rxIn = %0b = 0x%0h", $time, dataReg, dataReg);

            @(itf.rxDone);
            trans = new();
            trans.referData = dataReg;
            trans.rxDone = itf.rxDone;
            trans.rxOut = itf.rxOut;
            mon2scb.put(trans);
            $display("[%0t] [MON] rxOut = 0x%0h", $time, itf.rxOut);
            
            @(drv2mon);
            $display("[%0t] [MON] Stop bit %0d", $time, itf.rxIn);
        end
    endtask
endclass

class environment_uartRx;
    transaction_uartRx trans;
    generator_uartRx gen;
    driver_uartRx drv;
    mailbox #(transaction_uartRx) gen2drv;
    event txReq;
    event drv2mon;
    scoreboard_uartRx scb;
    monitor_uartRx mon;
    mailbox #(transaction_uartRx) mon2scb;
    event scb2gen;

    function new(virtual itf_uartRx itf);
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
            gen.run(10);
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
    itf_uartRx itf();
    baudTickGen #(.BPS(9600)) u_baudTickGen (.clk(itf.clk), .rst(itf.rst), .tick(itf.baudTick), .tickCnt(itf.baudTickCnt));
    uart_rx #(.BPS(9600)) uut (
        .clk(itf.clk), .rst(itf.rst),
        .baudTick(itf.baudTick), .baudTickCnt(itf.baudTickCnt),
        .dataIn(itf.rxIn),
        .done(itf.rxDone), .dataOut(itf.rxOut));

    initial itf.clk = 0;
    always #5 itf.clk = ~itf.clk;

    environment_uartRx env;

    initial begin
        $display("====================================================================================================");
        $display("                                      UART Rx Simulation Start                                      ");
        $display("====================================================================================================");
    
        env = new(itf);
        env.run();
    end

endmodule
