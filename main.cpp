#include <errno.h>
#include <fcntl.h>
#include <string.h>
#include <termios.h>
#include <unistd.h>
#include <cstdio>
#include <iostream>
#include <X11/Xlib.h>
#include <string>

//bluetooth io code adapted from a stackoverflow post...
int set_interface_attribs (int fd, int speed, int parity) {
    struct termios tty;
    memset (&tty, 0, sizeof tty);
    if (tcgetattr (fd, &tty) != 0)
    {
        printf("error %d from tcgetattr", errno);
        return -1;
    }
    
    cfsetospeed (&tty, speed);
    cfsetispeed (&tty, speed);
    
    tty.c_cflag = (tty.c_cflag & ~CSIZE) | CS8;     // 8-bit chars
    // disable IGNBRK for mismatched speed tests; otherwise receive break
    // as \000 chars
    tty.c_iflag &= ~IGNBRK;         // disable break processing
    tty.c_lflag = 0;                // no signaling chars, no echo,
    // no canonical processing
    tty.c_oflag = 0;                // no remapping, no delays
    tty.c_cc[VMIN]  = 0;            // read doesn't block
    tty.c_cc[VTIME] = 5;            // 0.5 seconds read timeout
    
    tty.c_iflag &= ~(IXON | IXOFF | IXANY); // shut off xon/xoff ctrl
    
    tty.c_cflag |= (CLOCAL | CREAD);// ignore modem controls,
    // enable reading
    tty.c_cflag &= ~(PARENB | PARODD);      // shut off parity
    tty.c_cflag |= parity;
    tty.c_cflag &= ~CSTOPB;
    tty.c_cflag &= ~CRTSCTS;
    
    if (tcsetattr (fd, TCSANOW, &tty) != 0)
    {
        printf("error %d from tcsetattr", errno);
        return -1;
    }
    return 0;
}

void set_blocking (int fd, int should_block) {
    struct termios tty;
    memset (&tty, 0, sizeof tty);
    if (tcgetattr (fd, &tty) != 0)
    {
        printf("error %d from tggetattr", errno);
        return;
    }
    
    tty.c_cc[VMIN]  = should_block ? 1 : 0;
    tty.c_cc[VTIME] = 5;            // 0.5 seconds read timeout
    
    if (tcsetattr (fd, TCSANOW, &tty) != 0)
        printf("error %d setting term attributes", errno);
}

//cursor coordinate capturing code adapted from https://rosettacode.org/wiki/Mouse_position#C
std::pair<uint16_t, uint16_t> get_coordinates() {
    Display *d;
    Window inwin;      /* root window the pointer is in */
    Window inchildwin; /* child win the pointer is in */
    int rootx, rooty; /* relative to the "root" window; we are not interested in these,
                       but we can't pass NULL */
    int childx, childy;  /* the values we are interested in */
    Atom atom_type_prop; /* not interested */
    int actual_format;   /* should be 32 after the call */
    unsigned int mask;   /* status of the buttons */
    unsigned long n_items, bytes_after_ret;
    Window *props; /* since we are interested just in the first value, which is
                    a Window id */
    
    /* default DISPLAY */
    d = XOpenDisplay(NULL);
    
    /* ask for active window (no error check); the client must be freedesktop
     compliant */
    (void)XGetWindowProperty(d, DefaultRootWindow(d),
                             XInternAtom(d, "_NET_ACTIVE_WINDOW", True),
                             0, 1, False, AnyPropertyType,
                             &atom_type_prop, &actual_format,
                             &n_items, &bytes_after_ret, (unsigned char**)&props);
    
    XQueryPointer(d, props[0], &inwin,  &inchildwin,
                  &rootx, &rooty, &childx, &childy, &mask);
    
    XFree(props);           /* free mem */
    (void)XCloseDisplay(d); /* and close the display */
    
    uint16_t x = static_cast<uint16_t>(childx);
    uint16_t y = static_cast<uint16_t>(childy);
    
    if (x > 32768) {
        x = 0;
    } else if (x > 640 && x <= 32768) {
        x = 639;
    }
    
    if (y > 32768) {
        y = 0;
    } else if (y > 480 && y <= 32768) {
        y = 479;
    }
    
    return std::make_pair(x, y);
}

int main() {
    char* portname = "/dev/tty.RNBT-EB90-RNI-SPP";
    int fd = open (portname, O_RDWR | O_NOCTTY | O_SYNC);
    if (fd < 0) {
        printf("error %d opening %s: %s", errno, portname, strerror (errno));
        return -1;
    }
    set_interface_attribs (fd, 9600, 0);  // set baud rate to 9600 bps, 8n1 (no parity)
    set_blocking (fd, 0);                // set no blocking
    
    std::cout << "Beginning socket io..." << std::endl;
    while (true) {
        std::pair<uint16_t, uint16_t> coordinate = get_coordinates();
        char x_low = coordinate.first & 0xFF;
        char x_high = coordinate.first >> 8;
        char y_low = coordinate.second & 0xFF;
        char y_high = coordinate.second >> 8;
        char data[] = {
            x_low,
            x_high,
            y_low,
            y_high
        };
        
        //640x480
        std::cout << "Cursor at: " << coordinate.first << ',' << coordinate.second << std::endl;
        
        std::cout << "Write: ";
        std::cout.flush();
        for (char foo : data) {
            int i = write(fd, &foo, 1);
            if (i == 1) {
                std::cout << std::bitset<8>(foo).to_string() << ' ';
                std::cout.flush();
            } else {
                std::cout << "\tFailed." << std::endl;
                std::cout.flush();
                break;
            }
            
        }
        usleep(16666);
        std::cout << std::endl;
        std::cout.flush();
    }
}

//    std::string val = "\n\rNEXSYS3 GPIO/UART DEMO!\n\n\r";
//    char buf [100];
//    std::string val = "\n\rNEXSYS3 GPIO/UART DEMO!\n\n\r";
//    for (char& foo : val) {
//        if (foo == '\n') {
//            std::cout << "\\n" << ' ';
//        } else if (foo == '\r') {
//            std::cout << "\\r" << ' ';
//        } else {
//            std::cout << foo << "  ";
//        }
//    }
//    std::cout << std::endl;
//    for (char& foo : val) {
//        std::cout << (int) foo << ' ';
//    }
//    std::cout << std::endl;
//Nexsys 3 Demo RX Code
//    while (true) {
//        int n = read(fd, buf, 1);
//        if (n > 0) {
//            if (buf[0] == '\n') {
//                std::cout << "\\n";
//            } else if (buf[0] == '\r') {
//                std::cout << "\\r";
//            } else {
//                std::cout << buf[0];
//            }
//            std::cout << '\t' << (int) buf[0] << std::endl;
//        }
//        usleep(104);
//    }
////    Binary Counter TX Code
//    unsigned char ohs = 0;
//    while (true) {
//        int i = write(fd, &ohs, 1);
//        if (i == 1) {
//            std::cout << "Write: " << (int) ohs << std::endl;
//        } else {
//            std::cout << "Failed." << std::endl;
//        }
//        ++ohs;
//        usleep(100000);
//    }
//    //Nexys 3 Demo TX Code
//    while (true) {
//        std::cout << "Write: ";
//        std::cout.flush();
//        for (char foo : val) {
//            int i = write(fd, &foo, 1);
//            if (i == 1) {
//                if (foo == '\n') {
//                    std::cout << "\\n";
//                } else if (foo == '\r') {
//                    std::cout << "\\r";
//                } else {
//                    std::cout << foo;
//                }
//                std::cout.flush();
//            } else {
//                std::cout << "\tFailed." << std::endl;
//                std::cout.flush();
//                break;
//            }
//            usleep(16666 * 10);
//        }
//        std::cout << std::endl;
//        std::cout.flush();
//    }
