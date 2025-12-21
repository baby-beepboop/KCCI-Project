`timescale 1ns / 1ps

interface itf_uartRx;
    reg clk, rst;

    logic       baudTick;
    logic [3:0] baudTickCnt;

    reg         rxIn;
    logic [7:0] rxOut;
    logic       rxDone;
endinterface

package pkg_uartRx;
    localparam CLKS_PER_BIT = 651 * 10;

    class transaction_uartRx;
        rand bit rxIn;
        logic [7:0] rxOut;
        logic rxDone;
        
        bit [7:0] referData;
    endclass

    class generator_uartRx;
        virtual itf_uartRx itf;
        transaction_uartRx trans;
        mailbox #(transaction_uartRx) gen2drv;
        event txReq;
        event scb2gen;

        function new(virtual itf_uartRx itf, mailbox #(transaction_uartRx) gen2drv, event txReq, event scb2gen);
            this.itf = itf;
            this.gen2drv = gen2drv;
            this.txReq = txReq;
            this.scb2gen = scb2gen;
        endfunction

        task run(int cnt);
            repeat(cnt) begin
                trans = new();

                wait(itf.baudTickCnt == 0);
                trans.rxIn = 1'b0;
                $display("[%0t] [GEN] Start bit", $time);
                gen2drv.put(trans);
                @(txReq);

                for (int i=0; i<8; i++) begin
                    trans.randomize();
                    $display("[%0t] [GEN] Data bit[%0d] = %0d", $time, i, trans.rxIn);
                    gen2drv.put(trans);
                    @(txReq);
                end

                trans.rxIn = 1'b1;
                $display("[%0t] [GEN] Stop bit", $time);
                gen2drv.put(trans);

                @(scb2gen);
                $display("----------------------------------------------------------------------------------------------------");
            end
        endtask
    endclass

    class driver_uartRx;
        virtual itf_uartRx itf;
        transaction_uartRx trans;
        mailbox #(transaction_uartRx) gen2drv;
        event txReq;
        event drv2mon;

        function new(virtual itf_uartRx itf, mailbox #(transaction_uartRx) gen2drv, event txReq, event drv2mon);
            this.itf = itf;
            this.gen2drv = gen2drv;
            this.txReq = txReq;
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
                -> txReq;
                repeat(8) #(CLKS_PER_BIT);

                for (int i=0; i<8; i++) begin
                    gen2drv.get(trans);
                    itf.rxIn = trans.rxIn;
                    $display("[%0t] [DRV] Data bit[%0d] = %0d", $time, i, trans.rxIn);
                    repeat(8) #(CLKS_PER_BIT);
                    -> drv2mon;
                    -> txReq;
                    repeat(8) #(CLKS_PER_BIT);
                end

                gen2drv.get(trans);
                itf.rxIn = trans.rxIn;
                $display("[%0t] [DRV] Stop bit %0d", $time, trans.rxIn);
                repeat(8) #(CLKS_PER_BIT);
                -> drv2mon;
                -> txReq;
                repeat(8) #(CLKS_PER_BIT);
            end
        endtask
    endclass
endpackage
