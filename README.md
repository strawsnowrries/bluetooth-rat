# bluetooth-rat

Connect to bluetooth module:
```BluetoothConnector --connect 00-06-66-eb-eb-90 --notify```

Compile main.cpp:
```g++ -o main main.cpp -I/usr/X11R6/include -L/usr/X11R6/lib -lX11```

Require XQuartz with X11 & macOS or Linux. Will not run on Windows.
