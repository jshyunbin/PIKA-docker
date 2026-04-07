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

The HTC Vive positioning tag requires a udev rule on the **host** machine. Docker cannot apply
udev rules at runtime, so this must be done before starting the container.

```bash
# Build the image first
docker build -t pika-ros .

# Extract the udev rule from the image and install it on the host
docker run --rm pika-ros cat /etc/udev/rules.d/81-vive.rules \
    | sudo tee /etc/udev/rules.d/81-vive.rules

# Reload udev rules
sudo udevadm control --reload-rules && sudo udevadm trigger

# Replug the USB wireless receiver after applying the rules
```

## Building the Image

```bash
docker build -t pika-ros .
```

The build clones `pika_ros`, builds librealsense 2.50.0 from source, and unpacks the pre-built
`pika_ros` install tree. It takes roughly 10–20 minutes the first time.

## Running the Container

```bash
docker run -it --rm \
    --privileged \
    --network host \
    -v /dev:/dev \
    -v $(pwd)/data:/home/agilex/data \
    pika-ros
```

- `--privileged` and `-v /dev:/dev` are required for USB device access (depth camera, fisheye camera, Vive receiver, serial port).
- `--network host` allows ROS communication with nodes on the host or other machines.
- `-v $(pwd)/data:/home/agilex/data` mounts a local directory for saving collected datasets.

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
bash start_sensor.bash
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

**Single gripper:**

```bash
source ~/pika_ros/install/setup.bash
roslaunch data_tools run_data_capture.launch \
    datasetDir:=/home/agilex/data \
    episodeIndex:=0
```

**Dual grippers:**

```bash
source ~/pika_ros/install/setup.bash
roslaunch data_tools run_multi_data_capture.launch \
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

## Troubleshooting

| Problem | Fix |
|---|---|
| USB device not found | Confirm udev rules are installed on the host and replug the USB receiver |
| `driver_openvr.so` not found during calibration | `sudo apt install libopenvr-dev` on the host, then rebuild the image |
| Calibration stalls (no output) | `rm ~/.config/libsurvive/config.json` and calibrate again |
| `error failures` not 0 after calibration | Check for direct sunlight or other infrared sources; verify base station FOV covers the tracker |
| TF coordinates jitter after a period of use | Recalibrate: `cd ~/pika_ros/install/lib && ./survive-cli --force-calibrate` |
| RealSense camera not detected | Run `rs-enumerate-devices` inside the container to verify the camera is visible |

