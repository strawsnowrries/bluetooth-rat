`timescale 1ns/10ps

module uart_tb ();
  parameter c_CLOCK_PERIOD_NS = 10;
  parameter c_CLKS_PER_BIT    = 10416;
  parameter c_BIT_PERIOD      = 104160;

  reg r_Clock = 0;
  reg r_Tx_DV = 0;
  wire w_Tx_Done;
  reg [7:0] r_Tx_Byte = 0;
  reg r_Rx_Serial = 1;
  wire [7:0] w_Rx_Byte;
  reg reset;

  // Takes in input byte and serializes it
  task UART_WRITE_BYTE;
    input [7:0] i_Data;
    integer     ii;
    begin

      // Send Start Bit
      r_Rx_Serial <= 1'b0;
      #(c_BIT_PERIOD);
      #1000;

      // Send Data Byte
      for (ii=0; ii<8; ii=ii+1)
        begin
          r_Rx_Serial <= i_Data[ii];
          #(c_BIT_PERIOD);
        end

      // Send Stop Bit
      r_Rx_Serial <= 1'b1;
      #(c_BIT_PERIOD);
     end
  endtask // UART_WRITE_BYTE


  uart_rx_ctrl UART_RX_INST( .uart_rx(r_Rx_Serial), .clk(r_Clock), .reset(reset), .done_rx(), .byte_rx(w_Rx_Byte));

  always
    #(c_CLOCK_PERIOD_NS/2) r_Clock <= !r_Clock;

  // Main Testing:
  initial
    begin
      reset <= 1;
      @(posedge r_Clock);
      @(posedge r_Clock);
      @(posedge r_Clock);
      @(posedge r_Clock);
      reset <= 0;
      @(posedge r_Clock);

      // Send a command to the UART (exercise Rx)
      @(posedge r_Clock);
      UART_WRITE_BYTE(8'h3F);
      @(posedge r_Clock);

      // Check that the correct command was received
      if (w_Rx_Byte == 8'h3F)
        $display("Test Passed - Correct Byte Received");
      else
        $display("Test Failed - Incorrect Byte Received");

    end

endmodule
