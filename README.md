# bluetooth-rat

## FPGA

Required files to compile bit file: 
`
vga_ctrl.v
hvsync_generator.v
uart_rtx_core.v
uart_rx_top.v
pin_config.ucf
`


## PC (macOS)

Connect to bluetooth module: ```BluetoothConnector --connect 00-06-66-eb-eb-90 --notify```

Compile main.cpp: ```g++ -o main main.cpp -I/usr/X11R6/include -L/usr/X11R6/lib -lX11```

Required files to compile computer Tx program: `main.cpp`

Require XQuartz with X11 & macOS. Will not run on Windows.
