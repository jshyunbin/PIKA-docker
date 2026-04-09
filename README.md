<div align="center">

# PIKA-docker

[![CI](https://img.shields.io/github/actions/workflow/status/jshyunbin/PIKA-docker/docker-publish.yml?label=CI)](https://github.com/jshyunbin/PIKA-docker/actions/workflows/docker-publish.yml)
[![Docker Pulls](https://img.shields.io/docker/pulls/jshyunbin/pika-ros)](https://hub.docker.com/r/jshyunbin/pika-ros)
[![Docker Image Size](https://img.shields.io/docker/image-size/jshyunbin/pika-ros/latest)](https://hub.docker.com/r/jshyunbin/pika-ros)

</div>

A Dockerized distribution of the AgileX PIKA's ROS software stack. PIKA is a spatial data
collection system for embodied intelligence research, consisting of:

- **Pika Sense** — handheld data collector (depth camera, fisheye camera, gripper, IMU, HTC Vive positioning tag)
- **Pika Gripper** — end-effector for robot arms (same sensor suite as Pika Sense)
- **Pika Station** — infrared positioning base stations (HTC Vive Lighthouse technology)

## Host Computer Requirements

| Item | Requirement |
|---|---|
| CPU | Intel i5 9th generation or above |
| Storage | 1 TB or more |
| USB ports | USB 3.0 × 3 (docking stations cannot be used) |

## Prerequisites

- Docker (20.10+)
- Pika Station base stations physically deployed and powered on (see §2.1 of the user manual)
- Positioning tag paired with its USB wireless receiver via SteamVR (first-time setup only, see §2.2 of the user manual)

## Host Setup (one-time)

Docker cannot apply udev rules at runtime. Device symlinks like `/dev/ttyUSB50` must be
created on the **host** before starting the container. This repo includes `setup_host.sh`
to handle this in one step.

```bash
# Clone this repo
git clone https://github.com/jshyunbin/PIKA-docker.git
cd PIKA-docker

# Run the host setup for your configuration:
#   single_sensor   — one Pika Sense (ttyUSB50, video50)
#   single_gripper  — one Pika Gripper (ttyUSB60, video60)
#   multi_sensor    — two Pika Sense units (ttyUSB50/51, video50/51)
#   multi_gripper   — two Pika Grippers (ttyUSB60/61, video60/61)
#   sensor_gripper  — one Pika Sense + one Pika Gripper (ttyUSB50/60, video50/60)
sudo bash setup_host.sh single_sensor

# Replug all USB devices after the script completes
```

> **Note:** `multi_*` and `sensor_gripper` modes use USB hub port positions (kernel paths)
> to distinguish between units. The default kernel paths in `scripts/setup_multi_*.bash`
> are Agilex reference values and **will not match most machines**. Follow the
> [Multi-device USB configuration](#multi-device-usb-configuration) section below before
> running these modes.

## Getting the Image

### Recommended: Pull from Docker Hub

```bash
docker pull jshyunbin/pika-ros
```

### Alternative: Build from source

The build clones `pika_ros`, builds librealsense from source, and unpacks the pre-built
`pika_ros` install tree. It takes roughly 10–20 minutes.

```bash
docker build -t jshyunbin/pika-ros .
```

## Running the Container

First, allow the container to connect to the host's X11 display (required for RViz):

```bash
xhost +local:docker
```

**Single Pika Sense:**

```bash
docker run -it --rm \
    --privileged \
    --network host \
    -v /dev:/dev \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -e DISPLAY=$DISPLAY \
    -v $(pwd)/data:/home/agilex/data \
    jshyunbin/pika-ros
```

**Dual Pika Sense** (after filling in serial numbers in `config/start_multi_sensor.bash`):

```bash
docker run -it --rm \
    --privileged \
    --network host \
    -v /dev:/dev \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -e DISPLAY=$DISPLAY \
    -v $(pwd)/data:/home/agilex/data \
    -v $(pwd)/config/start_multi_sensor.bash:/root/pika_ros/install/share/sensor_tools/scripts/start_multi_sensor.bash \
    jshyunbin/pika-ros
```

- `--privileged` and `-v /dev:/dev` are required for USB device access (depth camera, fisheye camera, Vive receiver, serial port).
- `--network host` allows ROS communication with nodes on the host or other machines.
- `-v /tmp/.X11-unix:/tmp/.X11-unix` and `-e DISPLAY=$DISPLAY` forward the host display so RViz can render.
- `-v $(pwd)/data:/home/agilex/data` mounts a local directory for saving collected datasets.
- `-v $(pwd)/config/start_multi_sensor.bash:...` mounts the pre-configured launch script so serial numbers persist across container restarts.

## Usage Workflow

### 1. Calibrate the positioning base station

Run this inside the container whenever you first set up, move a base station, change channels,
or add/remove stations. Hold the Pika Sense within the field of view of the base stations.

```bash
# First-time calibration (or after adding/removing stations)
cd ~/pika_ros/install/lib && ./survive-cli --force-calibrate
```

Wait until the terminal shows `seed runs` and `error failures 0`, then press **Ctrl+C** to stop.

> **Note:** The `Warning: Libusb poll failed. -10 (LIBUSB_ERROR_INTERRUPTED)` message that
> appears on Ctrl+C can be ignored — it does not affect positioning.

If calibration stalls (terminal stays still, no positioning error displayed), delete the stale
config and try again:

```bash
rm ~/.config/libsurvive/config.json
```

### 2. Launch the sensors

**Single Pika (one gripper):**

```bash
cd ~/pika_ros/install/share/sensor_tools/scripts/
bash start_single_sensor.bash
```

**Dual Pika (two grippers):**

First configure left/right camera and serial port assignments (see §2.6–2.7 of the user manual),
then:

```bash
cd ~/pika_ros/install/share/sensor_tools/scripts/
bash start_multi_sensor.bash
```

After launch, an RViz window will show the TF coordinate frame of the Pika. Verify that the
transform is stable and free of jitter before collecting data. Recalibrate if jitter is observed.

### 3. Collect data

**Single Pika Sense:**

```bash
source ~/pika_ros/install/setup.bash
roslaunch data_tools run_data_capture.launch \
    type:=single_pika \
    datasetDir:=/home/agilex/data \
    episodeIndex:=0
```

**Dual Pika Sense:**

```bash
source ~/pika_ros/install/setup.bash
roslaunch data_tools run_data_capture.launch \
    type:=multi_pika \
    datasetDir:=/home/agilex/data \
    episodeIndex:=0
```

Press **Enter** to end the collection. Data is saved under `datasetDir/episode<N>/`:

| Path | Format | Contents |
|---|---|---|
| `camera/color/pikaDepthCamera/` | `.png` | RGB frames from depth camera |
| `camera/color/fisheye/` | `.png` | Fisheye camera RGB frames |
| `camera/depth/pikaDepthCamera/` | `.png` | Depth frames |
| `camera/pointCloud/pikaDepthCamera/` | `.pcd` | Point clouds |
| `localization/pose/pikaLocator/` | `.json` | 6-DOF pose (x, y, z, roll, pitch, yaw) |
| `gripper/encoder/pika/` | `.json` | Gripper motor angle and distance |
| `imu/9axis/pika/` | `.json` | IMU angular velocity, acceleration, orientation |

## Multi-device USB configuration

When using two Pika units (`multi_sensor`, `multi_gripper`, or `sensor_gripper` mode), udev
must distinguish them by their USB hub port position (kernel path). These paths are
machine-specific — you must discover them before running `setup_host.sh`.

Do this once, with devices connected one at a time.

### Step 1 — Find the serial port kernel path

Connect **only** the first device (left sensor or left gripper). Then:

```bash
cd /dev && ls | grep ttyUSB           # e.g. ttyUSB0
udevadm info /dev/ttyUSB0             # look for the KERNELS line
```

In the output, find a line like:
```
E: ID_PATH_TAG=pci-0000_00_14.0-usb-0_6.4_1.0
```
or a `P:` path like `/devices/.../usb1/1-6/1-6.4/1-6.4:1.0/...` — the kernel path is
the last component before `/tty/`, e.g. **`1-6.4:1.0`**.

Unplug the first device, connect only the second, and repeat to get the second kernel path.

### Step 2 — Find the fisheye camera kernel path

With only one device connected:

```bash
for dev in /dev/video*; do
  echo "=== $dev ==="; udevadm info $dev | grep -E 'KERNELS|ID_VENDOR_ID|ID_MODEL_ID'
done
```

Find the entry with `ID_VENDOR_ID=1bcf` and `ID_MODEL_ID=2cd1` — that is the fisheye
camera. Note its `KERNELS` value (e.g. `1-6.3:1.0`). Repeat for the second device.

### Step 3 — Edit the setup script

Open the relevant script and replace the four KERNELS variables at the top:

```bash
# For two sensors:
nano scripts/setup_multi_sensor.bash

# For two grippers:
nano scripts/setup_multi_gripper.bash

# For one sensor + one gripper:
nano scripts/setup_sensor_gripper.bash
```

Then run `sudo bash setup_host.sh <mode>` and replug all devices.

### Step 4 — Configure depth camera left/right assignment

For `start_multi_sensor.bash` to record which hand is left and which is right, it needs
the RealSense serial numbers for each unit. With only one device connected:

```bash
rs-enumerate-devices | grep "Serial Number"
```

Note the serial number, unplug, connect the other device, repeat.

Then edit `config/start_multi_sensor.bash` in this repo and replace the two `CHANGE_ME` values:

```bash
l_depth_camera_no=230322273424   # ← your left RealSense serial
r_depth_camera_no=230322270988   # ← your right RealSense serial
```

This file is mounted into the container at runtime (see [Running the Container](#running-the-container)),
so changes here take effect immediately without rebuilding the image.

## Troubleshooting

| Problem | Fix |
|---|---|
| USB device not found | Confirm udev rules are installed on the host and replug the USB receiver |
| `driver_openvr.so` not found during calibration | `sudo apt install libopenvr-dev` on the host, then rebuild the image |
| Calibration stalls (no output) | `rm ~/.config/libsurvive/config.json` and calibrate again |
| `error failures` not 0 after calibration | Check for direct sunlight or other infrared sources; verify base station FOV covers the tracker |
| TF coordinates jitter after a period of use | Recalibrate: `cd ~/pika_ros/install/lib && ./survive-cli --force-calibrate` |
| RealSense camera not detected | Run `rs-enumerate-devices` inside the container to verify the camera is visible |

