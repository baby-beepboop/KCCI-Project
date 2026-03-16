`timescale 1ns / 1ps

module SCCB (

    input logic clk,
    input logic reset,
    input logic en,

    input logic [7:0] reg_addr,
    input logic [7:0] reg_data,

    output logic scl,
    output logic sda,
    output logic tx_done
);

  typedef enum logic [4:0] {
    IDLE,
    START1,
    START2,
    SLVAVE_ADDR1,
    SLVAVE_ADDR2,
    SLVAVE_ADDR3,
    SLVAVE_ADDR4,
    SLVAVE_ADDR_WAIT1,
    SLVAVE_ADDR_WAIT2,
    SLVAVE_ADDR_WAIT3,
    SLVAVE_ADDR_WAIT4,
    REGISTER_ADDR1,
    REGISTER_ADDR2,
    REGISTER_ADDR3,
    REGISTER_ADDR4,
    REGISTER_ADDR_WAIT1,
    REGISTER_ADDR_WAIT2,
    REGISTER_ADDR_WAIT3,
    REGISTER_ADDR_WAIT4,
    REGISTER_DATA1,
    REGISTER_DATA2,
    REGISTER_DATA3,
    REGISTER_DATA4,
    REGISTER_DATA_WAIT1,
    REGISTER_DATA_WAIT2,
    REGISTER_DATA_WAIT3,
    REGISTER_DATA_WAIT4,
    STOP1,
    STOP2,
    WAIT,
    LAST
  } STATE;

  STATE cur_state;
  STATE next_state;

  logic cur_scl, next_scl;
  logic cur_sda, next_sda;

  logic [2:0] cur_bit_cnt, next_bit_cnt;

  logic [19:0] cur_clk_cnt, next_clk_cnt;

  logic [7:0] cur_tx_data, next_tx_data;

  logic [7:0] slave_addr = 8'h42;  //0x0100001_0 마지막 비트는 write 0비트


  assign scl = (cur_scl == 0) ? 1'b0 : 1'bz;
  assign sda = (cur_sda == 0) ? 1'b0 : 1'bz;


  always_ff @(posedge clk, posedge reset) begin
    if (reset) begin
      cur_state   <= IDLE;
      cur_scl     <= 1;
      cur_sda     <= 1;
      cur_clk_cnt <= 0;
      cur_bit_cnt <= 0;
      cur_tx_data <= slave_addr;
    end else begin
      cur_state   <= next_state;
      cur_scl     <= next_scl;
      cur_sda     <= next_sda;
      cur_clk_cnt <= next_clk_cnt;
      cur_bit_cnt <= next_bit_cnt;
      cur_tx_data <= next_tx_data;
    end

  end


  always_comb begin
    next_state   = cur_state;
    next_scl     = cur_scl;
    next_sda     = cur_sda;
    next_clk_cnt = cur_clk_cnt;
    next_bit_cnt = cur_bit_cnt;
    next_tx_data = cur_tx_data;
    tx_done      = 0;
    case (cur_state)

      IDLE: begin
        next_sda = 1;
        next_scl = 1;
        next_tx_data = slave_addr;
        if (en) begin
          next_state = START1;
        end
      end

      START1: begin
        next_sda = 0;
        next_scl = 1;
        if (cur_clk_cnt == 499) begin
          next_state   = START2;
          next_clk_cnt = 0;
        end else begin
          next_clk_cnt = cur_clk_cnt + 1;
        end
      end

      START2: begin
        next_sda = 0;
        next_scl = 0;
        if (cur_clk_cnt == 499) begin
          next_state   = SLVAVE_ADDR1;
          next_clk_cnt = 0;
        end else begin
          next_clk_cnt = cur_clk_cnt + 1;
        end
      end
      SLVAVE_ADDR1: begin
        next_scl = 0;
        next_sda = cur_tx_data[7];

        if (cur_clk_cnt == 249) begin
          next_state   = SLVAVE_ADDR2;
          next_clk_cnt = 0;
        end else begin
          next_clk_cnt = cur_clk_cnt + 1;
        end

      end
      SLVAVE_ADDR2: begin
        next_scl = 1;
        next_sda = cur_tx_data[7];

        if (cur_clk_cnt == 249) begin
          next_state   = SLVAVE_ADDR3;
          next_clk_cnt = 0;
        end else begin
          next_clk_cnt = cur_clk_cnt + 1;
        end
      end
      SLVAVE_ADDR3: begin
        next_scl = 1;
        next_sda = cur_tx_data[7];

        if (cur_clk_cnt == 249) begin
          next_state   = SLVAVE_ADDR4;
          next_clk_cnt = 0;
        end else begin
          next_clk_cnt = cur_clk_cnt + 1;
        end

      end
      SLVAVE_ADDR4: begin
        next_scl = 0;
        next_sda = cur_tx_data[7];

        if (cur_clk_cnt == 249) begin
          next_clk_cnt = 0;
          if (cur_bit_cnt == 7) begin
            next_bit_cnt = 0;
            next_tx_data = reg_addr;
            next_state   = SLVAVE_ADDR_WAIT1;
          end else begin
            next_bit_cnt = cur_bit_cnt + 1;
            next_tx_data = {cur_tx_data[6:0], 1'b0};
            next_state   = SLVAVE_ADDR1;
          end
        end else begin
          next_clk_cnt = cur_clk_cnt + 1;
        end

      end

      SLVAVE_ADDR_WAIT1: begin
        next_scl = 0;
        next_sda = 1;

        if (cur_clk_cnt == 249) begin
          next_clk_cnt = 0;
          next_state   = SLVAVE_ADDR_WAIT2;
        end else begin
          next_clk_cnt = cur_clk_cnt + 1;
        end

      end

      SLVAVE_ADDR_WAIT2: begin
        next_scl = 1;
        next_sda = 1;

        if (cur_clk_cnt == 249) begin
          next_clk_cnt = 0;
          next_state   = SLVAVE_ADDR_WAIT3;
        end else begin
          next_clk_cnt = cur_clk_cnt + 1;
        end

      end

      SLVAVE_ADDR_WAIT3: begin
        next_scl = 1;
        next_sda = 1;

        if (cur_clk_cnt == 249) begin
          next_clk_cnt = 0;
          next_state   = SLVAVE_ADDR_WAIT4;
        end else begin
          next_clk_cnt = cur_clk_cnt + 1;
        end

      end

      SLVAVE_ADDR_WAIT4: begin
        next_scl = 0;
        next_sda = 1;

        if (cur_clk_cnt == 249) begin
          next_clk_cnt = 0;
          next_state   = REGISTER_ADDR1;
        end else begin
          next_clk_cnt = cur_clk_cnt + 1;
        end

      end

      REGISTER_ADDR1: begin

        next_scl = 0;
        next_sda = cur_tx_data[7];
        if (cur_clk_cnt == 249) begin
          next_state   = REGISTER_ADDR2;
          next_clk_cnt = 0;
        end else begin
          next_clk_cnt = cur_clk_cnt + 1;
        end

      end
      REGISTER_ADDR2: begin

        next_scl = 1;
        next_sda = cur_tx_data[7];
        if (cur_clk_cnt == 249) begin
          next_state   = REGISTER_ADDR3;
          next_clk_cnt = 0;
        end else begin
          next_clk_cnt = cur_clk_cnt + 1;
        end

      end
      REGISTER_ADDR3: begin

        next_scl = 1;
        next_sda = cur_tx_data[7];
        if (cur_clk_cnt == 249) begin
          next_state   = REGISTER_ADDR4;
          next_clk_cnt = 0;
        end else begin
          next_clk_cnt = cur_clk_cnt + 1;
        end

      end
      REGISTER_ADDR4: begin

        next_scl = 0;
        next_sda = cur_tx_data[7];

        if (cur_clk_cnt == 249) begin
          next_clk_cnt = 0;
          if (cur_bit_cnt == 7) begin
            next_bit_cnt = 0;
            next_tx_data = reg_data;
            next_state   = REGISTER_ADDR_WAIT1;
          end else begin
            next_bit_cnt = cur_bit_cnt + 1;
            next_tx_data = {cur_tx_data[6:0], 1'b0};
            next_state   = REGISTER_ADDR1;
          end
        end else begin
          next_clk_cnt = cur_clk_cnt + 1;
        end

      end

      REGISTER_ADDR_WAIT1: begin
        next_scl = 0;
        next_sda = 1;
        if (cur_clk_cnt == 249) begin
          next_clk_cnt = 0;
          next_state   = REGISTER_ADDR_WAIT2;
        end else begin
          next_clk_cnt = cur_clk_cnt + 1;
        end

      end

      REGISTER_ADDR_WAIT2: begin
        next_scl = 1;
        next_sda = 1;

        if (cur_clk_cnt == 249) begin
          next_clk_cnt = 0;
          next_state   = REGISTER_ADDR_WAIT3;
        end else begin
          next_clk_cnt = cur_clk_cnt + 1;
        end

      end

      REGISTER_ADDR_WAIT3: begin
        next_scl = 1;
        next_sda = 1;

        if (cur_clk_cnt == 249) begin
          next_clk_cnt = 0;
          next_state   = REGISTER_ADDR_WAIT4;
        end else begin
          next_clk_cnt = cur_clk_cnt + 1;
        end

      end

      REGISTER_ADDR_WAIT4: begin
        next_scl = 0;
        next_sda = 1;

        if (cur_clk_cnt == 249) begin
          next_clk_cnt = 0;
          next_state   = REGISTER_DATA1;
        end else begin
          next_clk_cnt = cur_clk_cnt + 1;
        end

      end

      REGISTER_DATA1: begin

        next_scl = 0;
        next_sda = cur_tx_data[7];
        if (cur_clk_cnt == 249) begin
          next_state   = REGISTER_DATA2;
          next_clk_cnt = 0;
        end else begin
          next_clk_cnt = cur_clk_cnt + 1;
        end

      end
      REGISTER_DATA2: begin

        next_scl = 1;
        next_sda = cur_tx_data[7];
        if (cur_clk_cnt == 249) begin
          next_state   = REGISTER_DATA3;
          next_clk_cnt = 0;
        end else begin
          next_clk_cnt = cur_clk_cnt + 1;
        end

      end
      REGISTER_DATA3: begin

        next_scl = 1;
        next_sda = cur_tx_data[7];
        if (cur_clk_cnt == 249) begin
          next_state   = REGISTER_DATA4;
          next_clk_cnt = 0;
        end else begin
          next_clk_cnt = cur_clk_cnt + 1;
        end

      end
      REGISTER_DATA4: begin

        next_scl = 0;
        next_sda = cur_tx_data[7];

        if (cur_clk_cnt == 249) begin
          next_clk_cnt = 0;
          if (cur_bit_cnt == 7) begin
            next_bit_cnt = 0;
            next_state   = REGISTER_DATA_WAIT1;
          end else begin
            next_bit_cnt = cur_bit_cnt + 1;
            next_tx_data = {cur_tx_data[6:0], 1'b0};
            next_state   = REGISTER_DATA1;
          end
        end else begin
          next_clk_cnt = cur_clk_cnt + 1;
        end

      end

      REGISTER_DATA_WAIT1: begin
        next_scl = 0;
        next_sda = 1;

        if (cur_clk_cnt == 249) begin
          next_clk_cnt = 0;
          next_state   = REGISTER_DATA_WAIT2;
        end else begin
          next_clk_cnt = cur_clk_cnt + 1;
        end

      end

      REGISTER_DATA_WAIT2: begin
        next_scl = 1;
        next_sda = 1;

        if (cur_clk_cnt == 249) begin
          next_clk_cnt = 0;
          next_state   = REGISTER_DATA_WAIT3;
        end else begin
          next_clk_cnt = cur_clk_cnt + 1;
        end

      end

      REGISTER_DATA_WAIT3: begin
        next_scl = 1;
        next_sda = 1;

        if (cur_clk_cnt == 249) begin
          next_clk_cnt = 0;
          next_state   = REGISTER_DATA_WAIT4;
        end else begin
          next_clk_cnt = cur_clk_cnt + 1;
        end

      end

      REGISTER_DATA_WAIT4: begin
        next_scl = 0;
        next_sda = 1;

        if (cur_clk_cnt == 249) begin
          next_clk_cnt = 0;
          next_state   = STOP1;
        end else begin
          next_clk_cnt = cur_clk_cnt + 1;
        end

      end

      STOP1: begin
        next_scl = 1;
        next_sda = 0;
        if (cur_clk_cnt == 499) begin
          next_clk_cnt = 0;
          next_state   = STOP2;

        end else next_clk_cnt = cur_clk_cnt + 1;

      end

      STOP2: begin
        next_scl = 1;
        next_sda = 1;
        if (cur_clk_cnt == 499) begin
          next_clk_cnt = 0;

          if ((reg_addr == 8'h12) && (reg_data == 8'h80)) begin
            next_state = WAIT;

          end else begin
            tx_done    = 1;
            next_state = IDLE;
          end

          if ((reg_addr == 8'h15) && (reg_data == 8'h00)) begin
            tx_done    = 1;
            next_state = LAST;
          end

        end else begin
          next_clk_cnt = cur_clk_cnt + 1;
        end
      end


      WAIT: begin
        next_scl = 1;
        next_sda = 1;

        if (cur_clk_cnt >= 500_000) begin
          next_clk_cnt = 0;
          tx_done = 1;
          next_state = IDLE;
        end else begin
          next_clk_cnt = cur_clk_cnt + 1;
        end

      end

      LAST: begin
        next_scl = 1;
        next_sda = 1;

      end

    endcase

  end

endmodule
