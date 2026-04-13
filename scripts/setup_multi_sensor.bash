#!/bin/bash
# HOST-ONLY: Run this on the host machine, not inside Docker.
# Maps two Pika Sense units to fixed device paths using USB hub port positions.
# Reads kernel paths from config/sensors.yaml — edit that file, not this one.

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
YAML="$SCRIPT_DIR/../config/sensors.yaml"

parse() {
    python3 -c "import yaml; d=yaml.safe_load(open('$YAML')); print(d['usb_kernels']['multi_sensor']['$1'])"
}

L_SERIAL_KERNELS=$(parse left_serial)
R_SERIAL_KERNELS=$(parse right_serial)
L_FISHEYE_KERNELS=$(parse left_fisheye)
R_FISHEYE_KERNELS=$(parse right_fisheye)

echo "multi_sensor kernels:"
echo "  left  serial:  $L_SERIAL_KERNELS"
echo "  right serial:  $R_SERIAL_KERNELS"
echo "  left  fisheye: $L_FISHEYE_KERNELS"
echo "  right fisheye: $R_FISHEYE_KERNELS"

cat > /etc/udev/rules.d/sensor_serial.rules <<EOF
ACTION=="add", KERNELS=="$L_SERIAL_KERNELS", SUBSYSTEMS=="usb", MODE:="0777", SYMLINK+="ttyUSB50"
ACTION=="add", KERNELS=="$R_SERIAL_KERNELS", SUBSYSTEMS=="usb", MODE:="0777", SYMLINK+="ttyUSB51"
EOF

cat > /etc/udev/rules.d/sensor_fisheye.rules <<EOF
ACTION=="add", KERNEL=="video*", ENV{ID_USB_INTERFACE_NUM}=="00", KERNELS=="$L_FISHEYE_KERNELS", SUBSYSTEMS=="usb", MODE:="0777", SYMLINK+="video50"
ACTION=="add", KERNEL=="video*", ENV{ID_USB_INTERFACE_NUM}=="00", KERNELS=="$R_FISHEYE_KERNELS", SUBSYSTEMS=="usb", MODE:="0777", SYMLINK+="video51"
EOF
