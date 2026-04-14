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
- **RealSense serial numbers** — find with `realsense-viewer` and match left/right
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

Once the entire setup process is done, you can skip steps 1-3 next time you start the container. 

## Running from previous container

Once the initial setup is complete, most steps are persistent and can be skipped:

**Normal session (everything already configured):**
```bash
bash start.sh [single|multi]   # reattaches to existing container
```
Then go straight to Usage §3 (launch sensors) → §4 (collect) → §5 (sync).

**After moving a base station:** redo Usage §1 (recalibrate).
**After swapping a USB device:** redo Setup §1 (update `sensors.yaml`) → §2 (reinstall udev rules), then recreate the container with `docker rm pika-ros && bash start.sh`.
**After swapping a Vive tracker:** redo Usage §2 (reassign L/R codes).

---

## Usage Workflow

### 1. Calibrate the positioning base station

Run inside the container on first setup or after moving/adding stations:

```bash
cd ~/pika_ros/install/lib && ./survive-cli --force-calibrate
```

Wait for `seed runs` / `error failures 0`, then press **Ctrl+C**.
If calibration stalls: `rm ~/.config/libsurvive/config.json` and retry.


### 2. Set L/R hand locators

```bash
roslaunch pika_locator get_code.launch
```

Identify left/right serial code and add it to `.bashrc`

```bash
echo 'export pika_L_code=LHR-EB902458' >> ~/.bashrc

echo 'export pika_R_code=LHR-FE98B2BE' >> ~/.bashrc
# or if the environment variables already exist edit it

source ~/.bashrc
```


Now all trackers, cameras and sensors are aligned. 

### 3. Launch the sensors

> ⚠️ You need a separate terminal running the below command for data collection

```bash
cd ~/pika_ros/install/share/sensor_tools/scripts/

bash start_single_sensor.bash   # single
bash start_multi_sensor.bash    # dual
```

Verify the TF frame in RViz is stable before collecting data.

### 4. Collect data

```bash
source ~/pika_ros/install/setup.bash
# single pika
roslaunch data_tools run_data_capture.launch type:=single_pika datasetDir:=/home/agilex/data  episodeIndex:=0

# multi pika
roslaunch data_tools run_data_capture.launch type:=multi_pika datasetDir:=/home/agilex/data  episodeIndex:=0
```

Press **Enter** to stop. Data is saved under `datasetDir/episode<N>/`:

| Path | Format | Contents |
|---|---|---|
| `camera/color/pikaDepthCamera/` | `.jpg` | RGB frames |
| `camera/color/pikaFisheyeCamera/` | `.jpg` | Fisheye frames |
| `camera/depth/pikaDepthCamera/` | `.png` | Depth frames |
| `localization/pose/pika/` | `.json` | 6-DOF pose |
| `gripper/encoder/pika/` | `.json` | Gripper encoder |

### 5. Sync data

```bash
source ~/pika_ros/install/setup.bash
# single pika
roslaunch data_tools run_data_sync.launch type:=single_pika datasetDir:=/home/agilex/data episodeIndex:=-1

# multi pika
roslaunch data_tools run_data_sync.launch type:=multi_pika datasetDir:=/home/agilex/data episodeIndex:=-1
```

> Always pass `type:=single_pika` or `type:=multi_pika` — the default `aloha` will crash.

### 6. Data conversion to HDF5

Convert PCD data first.
```bash
cd ~/pika_ros/scripts
# single pika
python3 camera_point_cloud_filter.py --datasetDir /home/agilex/data/ --type single_pika

# multi pika
python3 camera_point_cloud_filter.py --datasetDir /home/agilex/data/ --type multi_pika 
```

Then convert to HDF5 format.
```bash
cd ~/pika_ros/scripts
# single pika
python3 data_to_hdf5.py --datasetDir /home/agilex/data/ --type single_pika

# multi pika
python3 data_to_hdf5.py --datasetDir /home/agilex/data/ --type multi_pika
```

## Troubleshooting

| Problem | Fix |
|---|---|
| USB device not found | Check udev rules are installed; replug devices |
| Calibration stalls | `rm ~/.config/libsurvive/config.json` and retry |
| `error failures` not 0 | Remove infrared sources (sunlight); check base station FOV |
| TF jitter during use | Recalibrate: `cd ~/pika_ros/install/lib && ./survive-cli --force-calibrate` |
| RealSense not detected | Run `rs-enumerate-devices` inside container |

## Acknowledgement

- `scripts/find_usb_kernel.bash` code from [JHyoonirl/pika_ros2](https://github.com/JHyoonirl/pika_ros2/blob/main/scripts/find_addr.bash)