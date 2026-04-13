<div align="center">

# PIKA-docker

[![CI](https://img.shields.io/github/actions/workflow/status/jshyunbin/PIKA-docker/docker-publish.yml?label=CI)](https://github.com/jshyunbin/PIKA-docker/actions/workflows/docker-publish.yml)
[![Docker Pulls](https://img.shields.io/docker/pulls/jshyunbin/pika-ros)](https://hub.docker.com/r/jshyunbin/pika-ros)
[![Docker Image Size](https://img.shields.io/docker/image-size/jshyunbin/pika-ros/latest)](https://hub.docker.com/r/jshyunbin/pika-ros)

</div>

Dockerized ROS Noetic stack for the AgileX PIKA spatial data collection system.

## Prerequisites

- Docker 20.10+
- Ubuntu 20.04 host, i5 9th gen+, 1TB+ storage, USB 3.0 × 3 (no docking stations)
- Pika Station base stations deployed and powered on
- Positioning tag paired via SteamVR (first-time only)

## Setup

### 1. Clone and configure

```bash
git clone https://github.com/jshyunbin/PIKA-docker.git
cd PIKA-docker
```

Edit `config/sensors.yaml` with your machine-specific values:
- **RealSense serial numbers** — find with `rs-enumerate-devices | grep "Serial Number"` or realsense-viewer
- **USB kernel paths** (multi-device modes only) — find with `bash scripts/find_usb_kernel.bash` (connect one device at a time)

### 2. Install host udev rules

```bash
# Modes: single_sensor | single_gripper | multi_sensor | multi_gripper | sensor_gripper
sudo bash setup_host.sh single_sensor

# Replug all USB devices after the script completes
```

> For `multi_*` and `sensor_gripper` modes, fill in `usb_kernels` in `config/sensors.yaml` first.

### 3. Pull the image

```bash
docker pull jshyunbin/pika-ros
# or build locally: docker build -t jshyunbin/pika-ros .
```

### 4. Start the container

```bash
bash start.sh single   # single Pika Sense
bash start.sh multi    # dual Pika Sense
```

## Usage Workflow

### 1. Calibrate the positioning base station

Run inside the container on first setup or after moving/adding stations:

```bash
cd ~/pika_ros/install/lib && ./survive-cli --force-calibrate
```

Wait for `seed runs` / `error failures 0`, then press **Ctrl+C**.
If calibration stalls: `rm ~/.config/libsurvive/config.json` and retry.

### 2. Launch the sensors

```bash
cd ~/pika_ros/install/share/sensor_tools/scripts/

bash start_single_sensor.bash   # single
bash start_multi_sensor.bash    # dual
```

Verify the TF frame in RViz is stable before collecting data.

### 3. Collect data

```bash
source ~/pika_ros/install/setup.bash
roslaunch data_tools run_data_capture.launch \
    type:=single_pika \        # or multi_pika
    datasetDir:=/home/agilex/data \
    episodeIndex:=0
```

Press **Enter** to stop. Data is saved under `datasetDir/episode<N>/`:

| Path | Format | Contents |
|---|---|---|
| `camera/color/pikaDepthCamera/` | `.jpg` | RGB frames |
| `camera/color/pikaFisheyeCamera/` | `.jpg` | Fisheye frames |
| `camera/depth/pikaDepthCamera/` | `.png` | Depth frames |
| `localization/pose/pika/` | `.json` | 6-DOF pose |
| `gripper/encoder/pika/` | `.json` | Gripper encoder |

### 4. Sync data

```bash
source ~/pika_ros/install/setup.bash
roslaunch data_tools run_data_sync.launch \
    type:=single_pika \        # or multi_pika
    datasetDir:=/home/agilex/data \
    episodeIndex:=0
```

> Always pass `type:=single_pika` or `type:=multi_pika` — the default `aloha` will crash.

## Troubleshooting

| Problem | Fix |
|---|---|
| USB device not found | Check udev rules are installed; replug devices |
| Calibration stalls | `rm ~/.config/libsurvive/config.json` and retry |
| `error failures` not 0 | Remove infrared sources (sunlight); check base station FOV |
| TF jitter during use | Recalibrate: `cd ~/pika_ros/install/lib && ./survive-cli --force-calibrate` |
| RealSense not detected | Run `rs-enumerate-devices` inside container |
