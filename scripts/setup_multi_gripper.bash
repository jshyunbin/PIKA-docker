#!/bin/bash
# HOST-ONLY: Run this on the host machine, not inside Docker.
# Maps two Pika Gripper units to fixed device paths using USB hub port positions.
#
# IMPORTANT: The KERNELS values below are machine-specific. You MUST determine
# the correct values for your USB hub layout before running this script.
# See the README "Multi-device USB configuration" section for the full procedure.
#
# Summary of how to find your kernel paths:
#
# Step 1 — Serial port (ttyUSB) kernel path:
#   Connect ONLY the left gripper. Then:
#     cd /dev && ls | grep ttyUSB        # e.g. ttyUSB0
#     udevadm info /dev/ttyUSB0          # look for KERNELS line, e.g. 1-6.4:1.0
#   Repeat with ONLY the right gripper connected to get its kernel path.
#
# Step 2 — Fisheye camera (video) kernel path:
#   With ONLY the left gripper connected:
#     for dev in /dev/video*; do echo "$dev:"; udevadm info $dev | grep -E 'KERNELS|ID_VENDOR_ID|ID_MODEL_ID'; echo; done
#   Find the entry with ID_VENDOR_ID=1bcf and ID_MODEL_ID=2cd1. That KERNELS value
#   is the fisheye camera kernel path (e.g. 1-6.3:1.0).
#   Repeat for the right gripper.
#
# Fill in the four KERNELS values below, then run: sudo bash setup_host.sh multi_gripper

# ── Edit these four values ────────────────────────────────────────────────────
L_SERIAL_KERNELS="1-2.2.4:1.0"  # left gripper serial port  (from udevadm info /dev/ttyUSBX)
R_SERIAL_KERNELS="1-2.1.4:1.0"  # right gripper serial port
L_FISHEYE_KERNELS="1-2.2.3:1.0" # left gripper fisheye camera
R_FISHEYE_KERNELS="1-2.1.3:1.0" # right gripper fisheye camera
# ─────────────────────────────────────────────────────────────────────────────

cat > /etc/udev/rules.d/gripper_serial.rules <<EOF
ACTION=="add", KERNELS=="$L_SERIAL_KERNELS", SUBSYSTEMS=="usb", MODE:="0777", SYMLINK+="ttyUSB60"
ACTION=="add", KERNELS=="$R_SERIAL_KERNELS", SUBSYSTEMS=="usb", MODE:="0777", SYMLINK+="ttyUSB61"
EOF

cat > /etc/udev/rules.d/gripper_fisheye.rules <<EOF
ACTION=="add", KERNEL=="video*", ENV{ID_USB_INTERFACE_NUM}=="00", KERNELS=="$L_FISHEYE_KERNELS", SUBSYSTEMS=="usb", MODE:="0777", SYMLINK+="video60"
ACTION=="add", KERNEL=="video*", ENV{ID_USB_INTERFACE_NUM}=="00", KERNELS=="$R_FISHEYE_KERNELS", SUBSYSTEMS=="usb", MODE:="0777", SYMLINK+="video61"
EOF
