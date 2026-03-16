`timescale 1ns / 1ps

`include "uvm_macros.svh"
import uvm_pkg::*;

interface itf_sccb(input clk);
    logic rst;

    logic en;

    logic [7:0] regAddr, regData;

    wire scl, sda;

    wire txDone;

    // Open-drain
    assign (weak1, weak0) scl = 1'b1;
    assign (weak1, weak0) sda = 1'b1;
endinterface

class transaction_sccb extends uvm_sequence_item;
    `uvm_object_utils(transaction_sccb)

    rand logic en;
    rand logic [7:0] regAddr, regData;
    logic scl, sda;
    logic txDone;

    logic [7:0] collAddr, collData;

    function new(string name = "transaction_sccb");
        super.new(name);
    endfunction

    virtual function string conv2str;
        return $sformatf("en=%b, addr=0x%h, data=0x%h, done=%b", en, regAddr, regData, txDone);
    endfunction

endclass

// Subscriber: Functional Coverage 수집
class subscriber_sccb extends uvm_subscriber#(transaction_sccb);
    `uvm_component_utils(subscriber_sccb)

    transaction_sccb tr;

    covergroup sccb_cg;
        ADDR: coverpoint tr.collAddr {
            bins low  = {[8'h00:8'h3F]};
            bins mid  = {[8'h40:8'hBF]};
            bins high = {[8'hC0:8'hFF]};
        }
        DATA: coverpoint tr.collData {
            bins low  = {[8'h00:8'h7F]};
            bins high = {[8'h80:8'hFF]};
        }
        ADDR_X_DATA: cross ADDR, DATA;
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        sccb_cg = new();
    endfunction

    // 모니터에서 분석 포트로 넘어온 데이터를 받으면 호출됨
    virtual function void write(transaction_sccb t);
        this.tr = t;
        sccb_cg.sample();
    endfunction

endclass

class driver_sccb extends uvm_driver#(transaction_sccb);
    `uvm_component_utils(driver_sccb)

    virtual itf_sccb itf;
    uvm_analysis_port #(transaction_sccb) drv_ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drv_ap = new("drv_ap", this);
        if (!uvm_config_db#(virtual itf_sccb)::get(this, "", "itf", itf))
            `uvm_fatal("DRV", "Virtual Interface not found")
    endfunction

    virtual task run_phase(uvm_phase phase);
        itf.en <= 0;
        itf.regAddr <= 0; itf.regData <= 0;
        itf.rst <= 1;
        repeat(5) @(posedge itf.clk);
        itf.rst <= 0;
        repeat(5) @(posedge itf.clk);

        forever begin
            transaction_sccb tr;
            seq_item_port.get_next_item(tr);    // 시퀀서로부터 다음 아이템 요청
            drv_ap.write(tr);                   // 스코어보드에 예상값 전달
            driveItem(tr);                      // DUT 드라이빙
            seq_item_port.item_done();          // 완료 보고
        end
    endtask

    task driveItem(transaction_sccb tr);
        @(posedge itf.clk);
        itf.en <= tr.en;
        itf.regAddr <= tr.regAddr; itf.regData <= tr.regData;

        if (tr.en) begin
            @(posedge itf.txDone);
            `uvm_info("DRV", "DUT transmit done detected", UVM_HIGH)
            itf.en <= 0;
            repeat(100) @(posedge itf.clk);
        end
    endtask

endclass

class monitor_sccb extends uvm_monitor;
    `uvm_component_utils(monitor_sccb)

    virtual itf_sccb itf;
    uvm_analysis_port #(transaction_sccb) mon_ap;   // 스코어보드로 데이터를 보내는 포트

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        mon_ap = new("mon_ap", this);
        if (!uvm_config_db#(virtual itf_sccb)::get(this, "", "itf", itf))
            `uvm_fatal("MON", "Virtual Interface not found")
    endfunction

    // SCL/SDA 신호를 해석해 데이터 복원
    virtual task run_phase(uvm_phase phase);
        forever begin
            transaction_sccb tr;
            logic [7:0] slvAddr, regAddr, regData;

            // Start 조건 (SCL High, SDA Negedge)
//            `uvm_info("MON", "Waiting for start condition...", UVM_MEDIUM)
            while (1) begin
                @(negedge itf.sda);
                if (itf.scl === 1) break;
            end
//            `uvm_info("MON", "Start condition detected. Start collecting for data", UVM_LOW)

            tr = transaction_sccb::type_id::create("tr");

            // 데이터 수집
            collByte(slvAddr);
            `uvm_info("MON", $sformatf("Slave Addr: 0x%h", slvAddr), UVM_HIGH)
            collByte(regAddr);
            `uvm_info("MON", $sformatf("Register Addr: 0x%h", regAddr), UVM_HIGH)
            collByte(regData);
            `uvm_info("MON", $sformatf("Register Data: 0x%h", regData), UVM_HIGH)

            tr.collAddr = regAddr;
            tr.collData = regData;

            `uvm_info("MON", $sformatf("Recovered from SDA: Addr=0x%h, Data=0x%h", regAddr, regData), UVM_LOW);
            mon_ap.write(tr);

            // Stop 조건 (SCL High, SDA Posedge)
            while (1) begin
                @(posedge itf.sda);
                if (itf.scl === 1) break;
            end
//            `uvm_info("MON", "Stop condition detected", UVM_MEDIUM)
        end
    endtask

    task collByte(output logic [7:0] byteOut);
        for (int i=7; i>=0; i--) begin
            @(posedge itf.scl);
            byteOut[i] = itf.sda;
        end
        @(posedge itf.scl);
    endtask

endclass

class scoreboard_sccb extends uvm_scoreboard;
    `uvm_component_utils(scoreboard_sccb)
    
    `uvm_analysis_imp_decl(_drv)
    `uvm_analysis_imp_decl(_mon)

    uvm_analysis_imp_drv#(transaction_sccb, scoreboard_sccb) drv_imp;
    uvm_analysis_imp_mon#(transaction_sccb, scoreboard_sccb) mon_imp;

    transaction_sccb expectQ[$];    // 예상 데이터를 저장할 큐
    int passCnt = 0;
    int failCnt = 0;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drv_imp = new("drv_imp", this);
        mon_imp = new("mon_imp", this);
    endfunction

    // 드라이버가 보낸 정보를 큐에 저장
    virtual function void write_drv(transaction_sccb tr);
        expectQ.push_back(tr);
//        `uvm_info("SB", $sformatf("Save expected data (Queue size: %0d)", expectQ.size()), UVM_HIGH)
    endfunction

    // 모니터가 SDA에서 복원한 정보를 가져오면 큐와 비교
    virtual function void write_mon(transaction_sccb tr);
        transaction_sccb exp;
        if (expectQ.size() > 0) begin
            exp = expectQ.pop_front();
            if ((exp.regAddr == tr.collAddr) && (exp.regData == tr.collData)) begin
                `uvm_info("SB_CHECK", $sformatf("MATCH! SDA Protocol OK. Addr=0x%h, Data=0x%h", tr.collAddr, tr.collData), UVM_LOW);
                passCnt++;
            end
            else begin
                `uvm_error("SB_CHECK", $sformatf("MISMATCH! Addr=0x%h, Data=0x%h (Exp: 0x%h, 0x%h)", tr.collAddr, tr.collData, exp.regAddr, exp.regData))
                failCnt++;
            end
        end
        else begin
            `uvm_error("SB_CHECK", "Unexpected Monitor transaction received")
        end
    endfunction

    virtual function void report_phase(uvm_phase phase);
        `uvm_info("SB_REPORT", $sformatf("\n------------------------------\n FINAL PROTOCOL CHECK\n PASS: %0d\n FAIL: %0d\n------------------------------\n", passCnt, failCnt), UVM_LOW)
    endfunction

endclass

// Agent: 시퀀서, 드라이버, 모니터를 하나로 패키징
class agent_sccb extends uvm_agent;
    `uvm_component_utils(agent_sccb)

    driver_sccb drv;
    uvm_sequencer#(transaction_sccb) sqr;    // Sequencer: 트랜잭션을 드라이버에 전달하는 통로
    monitor_sccb mon;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drv = driver_sccb::type_id::create("drv", this);
        sqr = uvm_sequencer#(transaction_sccb)::type_id::create("sqr", this);
        mon = monitor_sccb::type_id::create("mon", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        drv.seq_item_port.connect(sqr.seq_item_export);    // 드라이버와 시퀀서 연결
    endfunction

endclass

class env_sccb extends uvm_env;
    `uvm_component_utils(env_sccb)

    agent_sccb agt;
    scoreboard_sccb sb;
    subscriber_sccb sub;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agt = agent_sccb::type_id::create("agt", this);
        sb = scoreboard_sccb::type_id::create("sb", this);
        sub = subscriber_sccb::type_id::create("sub", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        agt.mon.mon_ap.connect(sb.mon_imp);             // 모니터와 스코어보드 연결
        agt.drv.drv_ap.connect(sb.drv_imp);             // 드라이버와 스코어보드 연결
        agt.mon.mon_ap.connect(sub.analysis_export);    // 모니터와 Subscriber 연결
    endfunction

endclass

// 테스트 시나리오: 무작위 트랜잭션 생성
class seq_sccb extends uvm_sequence#(transaction_sccb);
    `uvm_object_utils(seq_sccb)

    function new(string name = "seq_sccb");
        super.new(name);
    endfunction

    virtual task body;
        repeat(50) begin
            req = transaction_sccb::type_id::create("req");
            start_item(req);
            if (!req.randomize() with {en == 1;})
                `uvm_error("SEQ", "Randomize failed")
            finish_item(req);
        end
    endtask

endclass

class test_sccb extends uvm_test;
    `uvm_component_utils(test_sccb)

    env_sccb env;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = env_sccb::type_id::create("env", this);
    endfunction

    // 드라이버와 시퀀서 연결 (UVM 통신 포트)
//    virtual function void connect_phase(uvm_phase phase);
//        drv.seq_item_port.connect(sqr.seq_item_export);
//    endfunction

    virtual task run_phase(uvm_phase phase);
        seq_sccb seq;
        phase.raise_objection(this);    // 테스트 시작 알림
        seq = seq_sccb::type_id::create("seq");
        seq.start(env.agt.sqr);         // 시퀀스 실행 (Env 내부의 시퀀서에 접근)
        #20_000_000;
        phase.drop_objection(this);     // 테스트 종료 알림
    endtask

endclass

module tb_sccb;
    bit clk;

    itf_sccb itf(clk);
    SCCB dut (
        .clk(clk), .reset(itf.rst),
        .en(itf.en),
        .reg_addr(itf.regAddr), .reg_data(itf.regData),
        .scl(itf.scl), .sda(itf.sda),
        .tx_done(itf.txDone));

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        uvm_config_db#(virtual itf_sccb)::set(null, "*", "itf", itf);
        run_test("test_sccb");
    end

    initial begin
        $fsdbDumpfile("build/wave.fsdb");
        $fsdbDumpvars(0);
    end

endmodule
