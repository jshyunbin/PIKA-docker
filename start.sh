#!/bin/bash
# Start the PIKA ROS Docker container.
# Usage: bash start.sh [single|multi]
# Default mode: single

set -e

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
MODE=${1:-single}
IMAGE=jshyunbin/pika-ros
CONTAINER_NAME=pika-ros
SENSORS_YAML="$SCRIPT_DIR/config/sensors.yaml"

if [[ "$MODE" != "single" && "$MODE" != "multi" ]]; then
    echo "Usage: bash start.sh [single|multi]"
    exit 1
fi

# Read serial numbers from config/sensors.yaml
if [ ! -f "$SENSORS_YAML" ]; then
    echo "Error: $SENSORS_YAML not found"
    exit 1
fi

if [ "$MODE" = "single" ]; then
    DEPTH_SN=$(python3 -c "import yaml; d=yaml.safe_load(open('$SENSORS_YAML')); print(d['realsense']['single']['depth_camera_serial'])")
    if [ "$DEPTH_SN" = "CHANGE_ME" ]; then
        echo "Warning: realsense.single.depth_camera_serial is not set in config/sensors.yaml"
    fi
else
    L_SN=$(python3 -c "import yaml; d=yaml.safe_load(open('$SENSORS_YAML')); print(d['realsense']['multi']['left_depth_camera_serial'])")
    R_SN=$(python3 -c "import yaml; d=yaml.safe_load(open('$SENSORS_YAML')); print(d['realsense']['multi']['right_depth_camera_serial'])")
    if [ "$L_SN" = "CHANGE_ME" ] || [ "$R_SN" = "CHANGE_ME" ]; then
        echo "Warning: one or more realsense serial numbers are not set in config/sensors.yaml"
    fi
fi

# Allow Docker to connect to the host X11 display (required for RViz)
xhost +local:docker

# Re-attach or start existing container if it exists
if docker inspect "$CONTAINER_NAME" &>/dev/null; then
    STATUS=$(docker inspect -f '{{.State.Status}}' "$CONTAINER_NAME")
    if [ "$STATUS" = "running" ]; then
        echo "Attaching to running container: $CONTAINER_NAME"
        docker attach "$CONTAINER_NAME"
    else
        echo "Restarting existing container: $CONTAINER_NAME"
        docker start -ai "$CONTAINER_NAME"
    fi
    exit 0
fi

# Build docker run arguments for a new container
DOCKER_ARGS=(
    -it
    --name "$CONTAINER_NAME"
    --privileged
    --network host
    -v /dev:/dev
    -v /tmp/.X11-unix:/tmp/.X11-unix
    -e DISPLAY="$DISPLAY"
    -v "$SCRIPT_DIR/data:/home/agilex/data"
)

if [ "$MODE" = "single" ]; then
    DOCKER_ARGS+=(-e DEPTH_CAMERA_SERIAL="$DEPTH_SN")
else
    DOCKER_ARGS+=(
        -e L_DEPTH_CAMERA_SERIAL="$L_SN"
        -e R_DEPTH_CAMERA_SERIAL="$R_SN"
    )
fi

echo "Starting new container in $MODE mode..."

SCRIPT_PATH=/root/pika_ros/install/share/sensor_tools/scripts/start_multi_sensor.bash

if [ "$MODE" = "multi" ]; then
    docker run "${DOCKER_ARGS[@]}" "$IMAGE" bash -c "
        sed -i 's/^l_depth_camera_no=.*/l_depth_camera_no=${L_SN}/' $SCRIPT_PATH &&
        sed -i 's/^r_depth_camera_no=.*/r_depth_camera_no=${R_SN}/' $SCRIPT_PATH &&
        exec bash
    "
else
    docker run "${DOCKER_ARGS[@]}" "$IMAGE"
fi
