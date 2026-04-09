#!/bin/bash
# HOST-ONLY: Run this on the host machine, not inside Docker.
# Maps one Pika Sense (ttyUSB50/video50) and one Pika Gripper (ttyUSB60/video60)
# using USB hub port positions.
#
# IMPORTANT: The KERNELS values below are machine-specific. You MUST determine
# the correct values for your USB hub layout before running this script.
# See the README "Multi-device USB configuration" section for the full procedure.
#
# Summary of how to find your kernel paths:
#
# Step 1 — Serial port (ttyUSB) kernel path:
#   Connect ONLY the sensor (or only the gripper). Then:
#     cd /dev && ls | grep ttyUSB        # e.g. ttyUSB0
#     udevadm info /dev/ttyUSB0          # look for KERNELS line, e.g. 1-6.4:1.0
#   Repeat with ONLY the other device connected.
#
# Step 2 — Fisheye camera (video) kernel path:
#   With ONLY the sensor (or gripper) connected:
#     for dev in /dev/video*; do echo "$dev:"; udevadm info $dev | grep -E 'KERNELS|ID_VENDOR_ID|ID_MODEL_ID'; echo; done
#   Find the entry with ID_VENDOR_ID=1bcf and ID_MODEL_ID=2cd1. That KERNELS value
#   is the fisheye camera kernel path (e.g. 1-6.3:1.0).
#   Repeat for the other device.
#
# Fill in the four KERNELS values below, then run: sudo bash setup_host.sh sensor_gripper

# ── Edit these four values ────────────────────────────────────────────────────
SENSOR_SERIAL_KERNELS="1-4.4:1.0"   # sensor serial port    (from udevadm info /dev/ttyUSBX)
GRIPPER_SERIAL_KERNELS="1-2.4:1.0"  # gripper serial port
SENSOR_FISHEYE_KERNELS="1-4.3:1.0"  # sensor fisheye camera
GRIPPER_FISHEYE_KERNELS="1-2.3:1.0" # gripper fisheye camera
# ─────────────────────────────────────────────────────────────────────────────

cat > /etc/udev/rules.d/sensor_serial.rules <<EOF
ACTION=="add", KERNELS=="$SENSOR_SERIAL_KERNELS", SUBSYSTEMS=="usb", MODE:="0777", SYMLINK+="ttyUSB50"
EOF

cat > /etc/udev/rules.d/gripper_serial.rules <<EOF
ACTION=="add", KERNELS=="$GRIPPER_SERIAL_KERNELS", SUBSYSTEMS=="usb", MODE:="0777", SYMLINK+="ttyUSB60"
EOF

cat > /etc/udev/rules.d/sensor_fisheye.rules <<EOF
ACTION=="add", KERNEL=="video[0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30,32,34,36,38,40,42,44,46,48]*", KERNELS=="$SENSOR_FISHEYE_KERNELS", SUBSYSTEMS=="usb", MODE:="0777", SYMLINK+="video50"
EOF

cat > /etc/udev/rules.d/gripper_fisheye.rules <<EOF
ACTION=="add", KERNEL=="video[0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30,32,34,36,38,40,42,44,46,48]*", KERNELS=="$GRIPPER_FISHEYE_KERNELS", SUBSYSTEMS=="usb", MODE:="0777", SYMLINK+="video60"
EOF
