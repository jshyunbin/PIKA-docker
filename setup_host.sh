#!/bin/bash
# Run once on the HOST machine before starting the Docker container.
# Usage: sudo bash setup_host.sh <mode>
# Modes: single_sensor | single_gripper | multi_sensor | multi_gripper | sensor_gripper

set -e

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

if [ -z "$1" ]; then
    echo "Usage: sudo bash setup_host.sh <mode>"
    echo "Modes: single_sensor | single_gripper | multi_sensor | multi_gripper | sensor_gripper"
    exit 1
fi

MODE=$1

# Always install Vive receiver udev rule
cp "$SCRIPT_DIR/udev/81-vive.rules" /etc/udev/rules.d/81-vive.rules
echo "Installed 81-vive.rules"

case "$MODE" in
    single_sensor)
        echo 'KERNEL=="ttyUSB*", ATTRS{idVendor}=="1a86", ATTRS{idProduct}=="7522", MODE:="0777", SYMLINK+="ttyUSB50"' \
            > /etc/udev/rules.d/sensor_serial.rules
        echo 'KERNEL=="video*", ENV{ID_USB_INTERFACE_NUM}=="00", ATTRS{idVendor}=="1bcf", ATTRS{idProduct}=="2cd1", MODE:="0777", SYMLINK+="video50"' \
            > /etc/udev/rules.d/sensor_fisheye.rules
        echo "Installed single sensor rules (ttyUSB50, video50)"
        ;;
    single_gripper)
        echo 'KERNEL=="ttyUSB*", ATTRS{idVendor}=="1a86", ATTRS{idProduct}=="7522", MODE:="0777", SYMLINK+="ttyUSB60"' \
            > /etc/udev/rules.d/gripper_serial.rules
        echo 'KERNEL=="video*", ENV{ID_USB_INTERFACE_NUM}=="00", ATTRS{idVendor}=="1bcf", ATTRS{idProduct}=="2cd1", MODE:="0777", SYMLINK+="video60"' \
            > /etc/udev/rules.d/gripper_fisheye.rules
        echo "Installed single gripper rules (ttyUSB60, video60)"
        ;;
    multi_sensor)
        bash "$SCRIPT_DIR/scripts/setup_multi_sensor.bash"
        echo "Installed multi sensor rules (ttyUSB50/51, video50/51)"
        ;;
    multi_gripper)
        bash "$SCRIPT_DIR/scripts/setup_multi_gripper.bash"
        echo "Installed multi gripper rules (ttyUSB60/61, video60/61)"
        ;;
    sensor_gripper)
        bash "$SCRIPT_DIR/scripts/setup_sensor_gripper.bash"
        echo "Installed sensor+gripper rules (ttyUSB50/60, video50/60)"
        ;;
    *)
        echo "Unknown mode: $MODE"
        echo "Modes: single_sensor | single_gripper | multi_sensor | multi_gripper | sensor_gripper"
        exit 1
        ;;
esac

udevadm control --reload-rules && service udev restart && udevadm trigger --action=add
echo ""
echo "Done. Replug all USB devices now."
