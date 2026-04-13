#!/bin/bash
# HOST-ONLY: Run this on the host machine, not inside Docker.
# Maps two Pika Gripper units to fixed device paths using USB hub port positions.
# Reads kernel paths from config/sensors.yaml — edit that file, not this one.

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
YAML="$SCRIPT_DIR/../config/sensors.yaml"

parse() {
    python3 -c "import yaml; d=yaml.safe_load(open('$YAML')); print(d['usb_kernels']['multi_gripper']['$1'])"
}

L_SERIAL_KERNELS=$(parse left_serial)
R_SERIAL_KERNELS=$(parse right_serial)
L_FISHEYE_KERNELS=$(parse left_fisheye)
R_FISHEYE_KERNELS=$(parse right_fisheye)

echo "multi_gripper kernels:"
echo "  left  serial:  $L_SERIAL_KERNELS"
echo "  right serial:  $R_SERIAL_KERNELS"
echo "  left  fisheye: $L_FISHEYE_KERNELS"
echo "  right fisheye: $R_FISHEYE_KERNELS"

cat > /etc/udev/rules.d/gripper_serial.rules <<EOF
ACTION=="add", KERNELS=="$L_SERIAL_KERNELS", SUBSYSTEMS=="usb", MODE:="0777", SYMLINK+="ttyUSB60"
ACTION=="add", KERNELS=="$R_SERIAL_KERNELS", SUBSYSTEMS=="usb", MODE:="0777", SYMLINK+="ttyUSB61"
EOF

cat > /etc/udev/rules.d/gripper_fisheye.rules <<EOF
ACTION=="add", KERNEL=="video*", ENV{ID_USB_INTERFACE_NUM}=="00", KERNELS=="$L_FISHEYE_KERNELS", SUBSYSTEMS=="usb", MODE:="0777", SYMLINK+="video60"
ACTION=="add", KERNEL=="video*", ENV{ID_USB_INTERFACE_NUM}=="00", KERNELS=="$R_FISHEYE_KERNELS", SUBSYSTEMS=="usb", MODE:="0777", SYMLINK+="video61"
EOF
