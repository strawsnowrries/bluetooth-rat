// --	The GPIO/UART Demo project demonstrates a simple usage of the Nexys3's
// -- GPIO and UART in an ISE design. The behavior is as follows:
// --
// --       *Switch 0 is used as a reset signal. The program will continuously
// --              send the same message over and over again to the receiving partner.
// --
// --	All UART communication can be captured by attaching the UART port to a
// -- computer running a Terminal program with 9600 Baud Rate, 8 data bits, no
// -- parity, and 1 stop bit.
// ----------------------------------------------------------------------------

`timescale 1ns / 1ps

module uart_top (
  MEM_OE, MEM_WR, RAM_CS, FLASH_CS, QUAD_SPI_FLASH_CS,
  CLK,
  // LED0, LED1, LED2, LED3, LED4, LED5, LED6, LED7,
  // BTNR, BTND, BTNL,
  // BTNC,
  // BTNU,
  SW0,
  // SW1, SW2, SW3, SW4, SW5, SW6, SW7,
  // CA, CB, CC, CD, CE, CF, CG, DP,
  // AN0, AN1, AN2, AN3,
  UART_TXD, PMODBT_RST, PMODBT_CTS);

  input CLK;
  input SW0;
  // input SW1, SW2, SW3, SW4, SW5, SW6, SW7;
  // input BTNR, BTND, BTNL;
  // input BTNC;
  // input BTNU;

  output MEM_OE, MEM_WR, RAM_CS, FLASH_CS, QUAD_SPI_FLASH_CS;
  // output LED0, LED1, LED2, LED3, LED4, LED5, LED6, LED7;
  // output CA, CB, CC, CD, CE, CF, CG, DP;
  // output AN0, AN1, AN2, AN3;
  output reg UART_TXD;
  output reg PMODBT_RST;
  output reg PMODBT_CTS;

  assign {MEM_OE, MEM_WR, RAM_CS, FLASH_CS, QUAD_SPI_FLASH_CS} = 5'b11111;

  // --The type definition for the UART state machine type. Here is a description of what
  // --occurs during each state:
  // -- RST_REG     -- Do Nothing. This state is entered after configuration or a user reset.
  // --                The state is set to LD_INIT_STR.
  // -- LD_INIT_STR -- The Welcome String is loaded into the sendStr variable and the strIndex
  // --                variable is set to zero. The welcome string length is stored in the StrEnd
  // --                variable. The state is set to SEND_CHAR.
  // -- SEND_CHAR   -- uartSend is set high for a single clock cycle, signaling the character
  // --                data at sendStr(strIndex) to be registered by the UART_TX_CTRL at the next
  // --                cycle. Also, strIndex is incremented (behaves as if it were post
  // --                incremented after reading the sendStr data). The state is set to RDY_LOW.
  // -- RDY_LOW     -- Do nothing. Wait for the READY signal from the UART_TX_CTRL to go low,
  // --                indicating a send operation has begun. State is set to WAIT_RDY.
  // -- WAIT_RDY    -- Do nothing. Wait for the READY signal from the UART_TX_CTRL to go high,
  // --                indicating a send operation has finished. If READY is high and strEnd =
  // --                StrIndex then state is set to WAIT_BTN, else if READY is high and strEnd /=
  // --                StrIndex then state is set to SEND_CHAR.

  localparam RST_REG = 3'b000, LD_INIT_STR = 3'b001, SEND_CHAR = 3'b010, RDY_LOW = 3'b011, WAIT_RDY = 3'b100;

  wire clk;
  assign clk = CLK;
  // BUFGP BUFGP1 (clk, CLK);

  wire reset;
  assign reset = SW0;

  localparam  MAX_STR_LEN = 27;

  //contains the current string being sent over uart.
  // reg[7:0] send_str[27:0] = "\n\rNEXSYS3 GPIO/UART DEMO!\n\n\r";
  reg[7:0] send_str[27:0] = "\r\n\n!OMED TRAU/OIPG 3SYSXEN\r\n";

  //contains the length of the current string being sent over uart.
  reg[7:0] str_end = 8'b00011011;

  //contains the index of the next character to be sent over uart within the sendStr variable.
  reg[7:0] str_index;

  //UART_TX_CTRL control signals
  wire uart_rdy;
  reg uart_send;
  reg[7:0] uart_data;
  wire uart_tx;

  reg[2:0] uart_state;

  always @ (posedge clk, posedge reset) begin : next_uart_state_process
    if (reset) begin
      uart_state <= RST_REG;
    end else begin
      case (uart_state)
        RST_REG: begin
          uart_state <= LD_INIT_STR;
        end

        LD_INIT_STR: begin
          uart_state <= SEND_CHAR;
        end

        SEND_CHAR: begin
          uart_state <= RDY_LOW;
        end

        RDY_LOW: begin
          uart_state <= WAIT_RDY;
        end

        WAIT_RDY: begin
          if (uart_rdy) begin
            if (MAX_STR_LEN == str_index) begin
              uart_state <= RST_REG;
            end else begin
              uart_state <= SEND_CHAR;
            end
          end
        end

        default: begin //should never be reached
          uart_state <= RST_REG;
        end
      endcase
	 end
  end

  //loads the sendStr and strEnd signals when a LD state is s reached.
  // always @ (posedge clk) begin : string_load_process
  //   if (uart_state == LD_INIT_STR) begin
  //     // send_str <= "\n\rNEXSYS3 GPIO/UART DEMO!\n\n\r";
  //     // str_end <= 26;
  //   end
  // end

  //controls the strIndex signal so that it contains the index of the next character that needs to be sent over uart
  always @ (posedge clk, posedge reset) begin : char_count_process
    if (reset) begin
      str_index <= 0;
    end else begin
      if (uart_state == LD_INIT_STR) begin
        str_index <= 0;
      end else if (uart_state == SEND_CHAR) begin
        str_index <= str_index + 1;
      end
    end
  end

  //controls the UART_TX_CTRL signals
  always @ (posedge clk, posedge reset) begin : char_load_process
    if (reset) begin
	   uart_send <= 1'b0;
     uart_data <= 8'b00000000;
    end else begin
      if (uart_state == SEND_CHAR) begin
        uart_send <= 1'b1;
        uart_data <= send_str[str_index];
      end else begin
        uart_send <= 0;
      end
    end
  end

  //component used to send a byte of data over a UART line.
  uart_tx_ctrl inst_uart_tx_ctrl( .send(uart_send), .data(uart_data), .clk(clk), .reset(reset), .ready(uart_rdy), .uart_tx(uart_tx));

  always @ (posedge clk, posedge reset) begin : misc
    if (reset) begin
      UART_TXD <= uart_tx;
      PMODBT_RST <= 1;
      PMODBT_CTS <= 0;
    end else begin
      UART_TXD <= uart_tx;
      PMODBT_RST <= 1;
      PMODBT_CTS <= 0;
    end
  end


endmodule // uart_top
