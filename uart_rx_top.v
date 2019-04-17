`timescale 1ns / 1ps

module uart_rx_top (
  MEM_OE, MEM_WR, RAM_CS, FLASH_CS, QUAD_SPI_FLASH_CS,
  CLK,
  LED0, LED1, LED2, LED3, LED4, LED5, LED6, LED7,
  // BTNR, BTND, BTNL,
  // BTNC,
  // BTNU,
  SW0,
  // SW1, SW2, SW3, SW4, SW5, SW6, SW7,
  // CA, CB, CC, CD, CE, CF, CG, DP,
  // AN0, AN1, AN2, AN3,
  UART_RXD, PMODBT_RST, PMODBT_CTS);

  input CLK;
  input SW0;
  // input SW1, SW2, SW3, SW4, SW5, SW6, SW7;
  // input BTNR, BTND, BTNL;
  // input BTNC;
  // input BTNU;

  output MEM_OE, MEM_WR, RAM_CS, FLASH_CS, QUAD_SPI_FLASH_CS;
  output LED0, LED1, LED2, LED3, LED4, LED5, LED6, LED7;
  // output CA, CB, CC, CD, CE, CF, CG, DP;
  // output AN0, AN1, AN2, AN3;
  input UART_RXD;
  output PMODBT_RST;
  output PMODBT_CTS;

  assign {MEM_OE, MEM_WR, RAM_CS, FLASH_CS, QUAD_SPI_FLASH_CS} = 5'b11111;

  wire clk;
  assign clk = CLK;

  wire reset;
  assign reset = SW0;

  //UART_RX_CTRL control signals
  wire uart_rx;
  assign uart_rx = UART_RXD;

  wire[7:0] byte_rx;
  wire done_rx;

  uart_rx_ctrl inst_uart_rx_ctrl( .uart_rx(uart_rx), .clk(clk), .reset(reset), .done_rx(done_rx), .byte_rx(byte_rx));

  reg[7:0] led_output;
  assign LED0 = led_output[0];
  assign LED1 = led_output[1];
  assign LED2 = led_output[2];
  assign LED3 = led_output[3];
  assign LED4 = led_output[4];
  assign LED5 = led_output[5];
  assign LED6 = led_output[6];
  assign LED7 = led_output[7];

  assign PMODBT_CTS = 0;
  assign PMODBT_RST = 1;
  always @ (posedge clk, posedge reset) begin
    if (reset) begin
      led_output <= 8'b11111111;
    end else begin
      led_output <= byte_rx;
    end
  end

endmodule // uart_top
