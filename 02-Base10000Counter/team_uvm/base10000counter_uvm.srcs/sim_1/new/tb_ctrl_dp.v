// tb_ctrl_dp v1.0.0: 컨트롤 유닛 + 카운터 datapath 테스트벤치
// 시뮬레이션 시나리오: 업 카운터 동작 -> i_runstop -> 업 카운터 일시정지 -> i_runstop -> 업 카운터 재개
//                   -> i_mode -> 다운 카운터 전환 -> i_clear -> 카운터 초기화 -> 업 카운터 동작
//                   -> i_set1234 -> 카운터 값 변경 -> 업 카운터 동작 -> i_mode -> 다운 카운터 동작
`timescale 1ns / 1ps

module tb_ctrl_dp;
    reg clk, rst;

    reg i_runstop, i_clear, i_mode, i_set;
    wire runstop, clear, mode, set;
    wire [13:0] cnt;

    control_unit u_control_unit (
        .clk(clk), .reset(rst),
        .i_runstop(i_runstop), .i_clear(i_clear), .i_mode(i_mode), .i_set1234(i_set),
        .o_runstop(runstop), .o_clear(clear), .o_mode(mode), .o_set1234(set));
    datapath_counter u_datapath_counter (
        .clk(clk), .reset(rst),
        .run_stop(runstop), .clear(clear), .mode(mode), .set_1234(set),
        .counter(cnt));

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        $display("=====================================================================================================");
        $display("                           Control Unit & Counter Datapah Simulation Start                           ");
        $display("=====================================================================================================");

        rst = 1;
        i_runstop = 0; i_clear = 0; i_mode = 0; i_set = 0;
        #100 rst = 0;
        $display("[%0t] Reset released", $time);

        // Step 1: 업 카운터 동작
        $display("[%0t] runstop=%0d (1: Run, 0: Stop), clear=%0d, mode=%0d (1: Down, 0: Up), set=%0d", $time, runstop, clear, mode, set);
        #450000000;

        // Step 2: 업 카운터 일시정지
        i_runstop = 1'b1;
        $display("[%0t] i_runstop high", $time);
        #10 i_runstop = 1'b0;
        $display("[%0t] runstop=%0d (1: Run, 0: Stop), clear=%0d, mode=%0d (1: Down, 0: Up), set=%0d", $time, runstop, clear, mode, set);
        #100000000;

        // Step 3: 업 카운터 재개
        i_runstop = 1'b1;
        $display("[%0t] i_runstop high", $time);
        #10 i_runstop = 1'b0;
        $display("[%0t] runstop=%0d (1: Run, 0: Stop), clear=%0d, mode=%0d (1: Down, 0: Up), set=%0d", $time, runstop, clear, mode, set);
        #300000000;

        // Step 4: 다운 카운터 전환
        i_mode = 1'b1;
        $display("[%0t] i_mode high", $time);
        #10 i_mode = 1'b0;
        $display("[%0t] runstop=%0d (1: Run, 0: Stop), clear=%0d, mode=%0d (1: Down, 0: Up), set=%0d", $time, runstop, clear, mode, set);
        #300000000;

        // Step 5: 카운터 초기화 후 업 카운터 동작
        i_clear = 1'b1;
        $display("[%0t] i_clear high", $time);
        #10 i_clear = 1'b0;
        $display("[%0t] runstop=%0d (1: Run, 0: Stop), clear=%0d, mode=%0d (1: Down, 0: Up), set=%0d", $time, runstop, clear, mode, set);
        #300000000;

        // Step 6: 카운터 값 변경 후 업 카운터 동작
        i_set = 1'b1;
        $display("[%0t] i_set high", $time);
        #10 i_set = 1'b0;
        $display("[%0t] runstop=%0d (1: Run, 0: Stop), clear=%0d, mode=%0d (1: Down, 0: Up), set=%0d", $time, runstop, clear, mode, set);
        #300000000;

        // Step 7: 다운 카운터 동작
        i_mode = 1'b1;
        $display("[%0t] i_mode high", $time);
        #10 i_mode = 1'b0;
        $display("[%0t] runstop=%0d (1: Run, 0: Stop), clear=%0d, mode=%0d (1: Down, 0: Up), set=%0d", $time, runstop, clear, mode, set);
        #500000000;

        $stop;
    end

endmodule
