`timescale 1ns / 1ps

module uart_rx_ctrl (uart_rx, clk, reset, done_rx, byte_rx);
  input uart_rx;
  input clk;
  input reset;
  output done_rx;
  output[7:0] byte_rx;

  localparam  LISTEN = 3'b000, RX_START = 3'b001, RX_DATA = 3'b010, RX_STOP = 3'b011, DONE = 3'b100;
  reg[2:0] rx_state;

  //100MHZ/9600 BAUD = 10416, need to wait 10416 clk cycles between every rx
  localparam bit_tmr_max = 10416;
  localparam bit_tmr_half = 5208;

  //clock cycle counter, on the 10416th clock cycle it is 1 baud...
  reg[13:0] bit_tmr;

  reg done; //combinatorial logic that goes high? when bit_tmr has counted to the proper value to ensure a 9600 baud rate
  reg[7:0] byte_data;
  reg[2:0] bit_index; //contains the index of the bit

  assign done_rx = done;
  assign byte_rx[0] = byte_data[0];
  assign byte_rx[1] = byte_data[1];
  assign byte_rx[2] = byte_data[2];
  assign byte_rx[3] = byte_data[3];
  assign byte_rx[4] = byte_data[4];
  assign byte_rx[5] = byte_data[5];
  assign byte_rx[6] = byte_data[6];
  assign byte_rx[7] = byte_data[7];

  always @ (posedge clk, posedge reset) begin : next_state_logic
    if (reset) begin
      rx_state <= LISTEN;
      bit_tmr <= 0;
      done <= 0;
      byte_data <= 0;
      bit_index <= 0;

    end else begin
      case (rx_state)
        LISTEN: begin
          done <= 0;
          bit_tmr <= 0;
          bit_index <= 0;

          if (uart_rx == 0) begin
            //start bit detected
            rx_state <= RX_START;
          end else begin
            rx_state <= LISTEN;
          end
        end

        RX_START: begin
          if (bit_tmr == bit_tmr_half) begin
            if (uart_rx == 0) begin
              //it is still low halfway through the BAUD, this must be a start bit.
              bit_tmr <= 0; //reset the counter to 0
              rx_state <= RX_DATA;
            end else begin
              rx_state <= LISTEN;
            end
          end else begin
            bit_tmr <= bit_tmr + 1;
            rx_state <= RX_START;
          end
        end

        // Wait CLKS_PER_BIT-1 clock cycles to sample serial data
        RX_DATA: begin
          if (bit_tmr < bit_tmr_max) begin
            bit_tmr <= bit_tmr + 1;
            rx_state <= RX_DATA;
          end else begin
            bit_tmr <= 0; //reset the counter back to 0
            byte_data[bit_index] <= uart_rx;

            if (bit_index < 7) begin
              bit_index <= bit_index + 1;
              rx_state <= RX_DATA;
            end else begin
              bit_index <= 0;
              rx_state <= RX_STOP;
            end
          end
        end

        // Receive Stop bit.  Stop bit = 1
        RX_STOP: begin
          if (bit_tmr < bit_tmr_max) begin
          // Wait CLKS_PER_BIT-1 clock cycles for Stop bit to finish
            bit_tmr <= bit_tmr + 1;
            rx_state <= RX_STOP;
          end else begin
            //signal to the upper layer that we have finished receiving the byte
            done <= 1;
            bit_tmr <= 0;
            rx_state <= DONE;
          end
        end

        DONE: begin
          //turn off the signal
          done <= 0;
          rx_state <= LISTEN;
        end

        default: begin //should never be reached
          rx_state <= LISTEN;
        end
      endcase
    end
  end
endmodule // uart_rx_ctrl

//------------------------------------------------------------------------------
// --	This component may be used to transfer data over a UART device. It will
// -- serialize a byte of data and transmit it over a TXD line. The serialized
// -- data has the following characteristics:
// --         *9600 Baud Rate
// --         *8 data bits, LSB first
// --         *1 stop bit
// --         *no parity
// --
// -- Port Descriptions:
// --
// --    SEND - Used to trigger a send operation. The upper layer logic should
// --           set this signal high for a single clock cycle to trigger a
// --           send. When this signal is set high DATA must be valid . Should
// --           not be asserted unless READY is high.
// --    DATA - The parallel data to be sent. Must be valid the clock cycle
// --           that SEND has gone high.
// --    CLK  - A 100 MHz clock is expected
// --   READY - This signal goes low once a send operation has begun and
// --           remains low until it has completed and the module is ready to
// --           send another byte.
// -- UART_TX - This signal should be routed to the appropriate TX pin of the
// --           external UART device.
// --
// ----------------------------------------------------------------------------
module uart_tx_ctrl (send, data, clk, reset, ready, uart_tx);
  input send;
  input[7:0] data;
  input clk;
  input reset;
  output ready;
  output uart_tx;

  localparam RDY = 2'b00, LOAD_BIT = 2'b01, SEND_BIT = 2'b10;
  reg[1:0] txstate; //states are RDY, LOAD_BIT, SEND_BIT

  //100MHZ divided by 9600 BAUD = 10416.66... cycles, we need to wait 10416 clk cycles between every bit-transmission
  localparam bit_tmr_max = 10416;

  //10 bit long message, 1 start bit, 8 data bits, 1 stop bit.
  localparam bit_index_max = 10;

  //this is used to count how many clock cycles have passed, on the 10416th clock cycle it is 1 baud...
  reg[13:0] bittmr; //counter that keeps track of the number of clock cycles the current bit has been held stable over the UART TX line.

  reg bitdone; //combinatorial logic that goes high when bittmr has counted to the proper value to ensure a 9600 baud rate

  reg[31:0] bitindex; //contains the index of the next bit in txData that needs to be transferred

  reg txbit; //a register that holds the current data being sent over the UART TX line

  reg[9:0] txdata; //a register that contains the whole data packet to be sent, including start and stop bits.

  //next state logic
  always @ (posedge clk, posedge reset) begin : next_state_logic
    if (reset) begin
      txstate <= RDY;
    end else begin
      case (txstate)
        RDY: begin
          if (send)
            txstate <= LOAD_BIT;
        end

        LOAD_BIT: begin
          txstate <= SEND_BIT;
        end

        SEND_BIT: begin
          if (bitdone) begin
            if (bitindex == bit_index_max) begin
              txstate <= RDY;
            end else begin
              txstate <= LOAD_BIT;
            end
          end
        end

        default: begin //should never be reached
          txstate <= RDY;
        end
      endcase
    end
  end

  always @ (posedge clk, posedge reset) begin : bit_timing_process
    if (reset) begin
      bittmr <= 14'b00000000000000;
      bitdone <= 0;
    end else begin
      if (txstate == RDY) begin
          bittmr <= 0;
      end else begin
        if (bitdone) begin
          bittmr <= 0;
        end else begin
          bittmr <= bittmr + 1;
        end

        if (bittmr == bit_tmr_max) begin
          //this was the 10416th clock, signal that we have waited 1 BAUD and we can move onto the next bit
          bitdone <= 1'b1;
        end else begin
          //still holding the current bit, not the 10416th clock yet...
          bitdone <= 1'b0;
        end
      end
    end
  end

  always @ (posedge clk, posedge reset) begin : bit_counting_process
    if (reset) begin
      bitindex <= 0;
    end else begin
      if (txstate == RDY) begin
        bitindex <= 0;
      end else if (txstate == LOAD_BIT) begin
        bitindex <= bitindex + 1;
      end
    end
  end

  always @ (posedge clk, posedge reset) begin : tx_data_latch_process
    if (reset) begin
      txdata <= 10'b1XXXXXXXX0;
    end else begin
      if (send) begin
        //set the txdata to 1 start bit 1'b1, 8 data bits, 1 stop bit 0'b0
        txdata <= {1'b1, data, 1'b0};
      end
    end
  end

  always @ (posedge clk, posedge reset) begin : tx_bit_process
    if (reset) begin
      txbit <= 1;
    end else begin
      if (txstate == RDY) begin
        txbit <= 1;
      end else if (txstate == LOAD_BIT) begin
        //set the bit to transmit to the value of txdata at index bitindex
        txbit <= txdata[bitindex];
      end
    end
  end

  //uart_tx is routed to the top, which is then routed to the PMODTX pin and transmitted
  assign uart_tx = txbit;
  assign ready = (txstate == RDY) ? 1'b1 : 1'b0;

endmodule // uart_tx_ctrl
