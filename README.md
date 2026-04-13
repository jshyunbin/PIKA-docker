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
- Pika Station base stations physically deployed and powered on 
- Positioning tag paired with its USB wireless receiver via SteamVR 

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


## Running the Container

First, edit `config/sensors.yaml` and fill in your RealSense depth camera serial numbers
(find them with `rs-enumerate-devices | grep "Serial Number"` or realsense-viewer).

Then start the container with:

```bash
# Single Pika Sense
bash start.sh single

# Dual Pika Sense
bash start.sh multi
```

`start.sh` handles X11 setup, removes any existing container with the same name,
injects serial numbers as environment variables, and mounts the correct config files.

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
| `camera/color/pikaDepthCamera/` | `.jpg` | RGB frames from depth camera |
| `camera/color/pikaFisheyeCamera/` | `.jpg` | Fisheye camera frames |
| `camera/depth/pikaDepthCamera/` | `.png` | Depth frames |
| `localization/pose/pika/` | `.json` | 6-DOF pose (x, y, z, roll, pitch, yaw) |
| `gripper/encoder/pika/` | `.json` | Gripper motor angle and distance |

### 4. Sync data

**Single Pika Sense:**

```bash
source ~/pika_ros/install/setup.bash
roslaunch data_tools run_data_sync.launch \
    type:=single_pika \
    datasetDir:=/home/agilex/data \
    episodeIndex:=1
```

**Dual Pika Sense:**

```bash
source ~/pika_ros/install/setup.bash
roslaunch data_tools run_data_sync.launch \
    type:=multi_pika \
    datasetDir:=/home/agilex/data \
    episodeIndex:=2
```

> **Note:** Always pass `type:=single_pika` or `type:=multi_pika`. The default is `aloha`
> which looks for different directory names and will immediately crash.

## Multi-device USB configuration

When using two Pika units (`multi_sensor`, `multi_gripper`, or `sensor_gripper` mode), udev
must distinguish them by their USB hub port position (kernel path). These paths are
machine-specific — you must discover them before running `setup_host.sh`.

Do this once, with devices connected one at a time.

### Step 1 — Find kernel paths with find_usb_kernel.bash

Connect **only** the first device (left sensor or left gripper), then run:

```bash
bash scripts/find_usb_kernel.bash
```

The script prints the kernel path for each connected ttyUSB and fisheye camera, for example:

```
[1] Serial Port (ttyUSB)
  Device : /dev/ttyUSB0
  Address: 1-6.4

[2] Fisheye Camera
  Device : /dev/video7
  Address: 1-6.3
```

Note the addresses. Unplug the first device, connect only the second, and run the script again.

### Step 2 — Edit sensors.yaml

Open `config/sensors.yaml` and fill in the four kernel values under the relevant mode:

```yaml
usb_kernels:
  multi_sensor:
    left_serial:   1-6.4:1.0   # ← your value from Step 1 (left)
    right_serial:  1-5.4:1.0   # ← your value from Step 1 (right)
    left_fisheye:  1-6.3:1.0   # ← your value from Step 2 (left)
    right_fisheye: 1-5.3:1.0   # ← your value from Step 2 (right)
```

Then run `sudo bash setup_host.sh <mode>` and replug all devices.

### Step 3 — Configure depth camera left/right assignment

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

