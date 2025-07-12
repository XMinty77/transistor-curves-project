using LibSerialPort
using REPL.TerminalMenus

# Initializes the serial communication with the Arduino
function serial_init()
    # Find and open the serial port
    device = serial_find()
    serial_port = LibSerialPort.open(device, 9600)
    # set_read_timeout(serial_port, 1)

    # Cleanup on exit
    atexit() do
        close(serial_port)
    end

    return serial_port
end

function serial_find()
    # Look for devices like /dev/ttyACMX
    devices = filter(x -> occursin(r"^ttyACM\d+$", x), readdir("/dev"))

    if length(devices) == 1
        # Only one device
        dev = "/dev/$(devices[1])"
        println("Found Arduino connected: $dev")
        return dev
    elseif isempty(devices)
        # No devices, we dip
        println("No Arduino connected found.")
        exit(1)
    else
        # Multiple devices, present a choice
        device = -1

        # Must choose a device
        while (device == -1)
            device = request("Multiple ttyACM devices found, please choose one:", RadioMenu("/dev/" .* devices, pagesize=4))
        end

        return "/dev/$(devices[device])"
    end
end