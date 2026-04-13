#!/bin/bash
# HOST-ONLY: Run this on the host machine, not inside Docker.
# Maps one Pika Sense (ttyUSB50/video50) and one Pika Gripper (ttyUSB60/video60).
# Reads kernel paths from config/sensors.yaml — edit that file, not this one.

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
YAML="$SCRIPT_DIR/../config/sensors.yaml"

parse() {
    python3 -c "import yaml; d=yaml.safe_load(open('$YAML')); print(d['usb_kernels']['sensor_gripper']['$1'])"
}

SENSOR_SERIAL_KERNELS=$(parse sensor_serial)
GRIPPER_SERIAL_KERNELS=$(parse gripper_serial)
SENSOR_FISHEYE_KERNELS=$(parse sensor_fisheye)
GRIPPER_FISHEYE_KERNELS=$(parse gripper_fisheye)

echo "sensor_gripper kernels:"
echo "  sensor  serial:  $SENSOR_SERIAL_KERNELS"
echo "  gripper serial:  $GRIPPER_SERIAL_KERNELS"
echo "  sensor  fisheye: $SENSOR_FISHEYE_KERNELS"
echo "  gripper fisheye: $GRIPPER_FISHEYE_KERNELS"

cat > /etc/udev/rules.d/sensor_serial.rules <<EOF
ACTION=="add", KERNELS=="$SENSOR_SERIAL_KERNELS", SUBSYSTEMS=="usb", MODE:="0777", SYMLINK+="ttyUSB50"
EOF

cat > /etc/udev/rules.d/gripper_serial.rules <<EOF
ACTION=="add", KERNELS=="$GRIPPER_SERIAL_KERNELS", SUBSYSTEMS=="usb", MODE:="0777", SYMLINK+="ttyUSB60"
EOF

cat > /etc/udev/rules.d/sensor_fisheye.rules <<EOF
ACTION=="add", KERNEL=="video*", ENV{ID_USB_INTERFACE_NUM}=="00", KERNELS=="$SENSOR_FISHEYE_KERNELS", SUBSYSTEMS=="usb", MODE:="0777", SYMLINK+="video50"
EOF

cat > /etc/udev/rules.d/gripper_fisheye.rules <<EOF
ACTION=="add", KERNEL=="video*", ENV{ID_USB_INTERFACE_NUM}=="00", KERNELS=="$GRIPPER_FISHEYE_KERNELS", SUBSYSTEMS=="usb", MODE:="0777", SYMLINK+="video60"
EOF
