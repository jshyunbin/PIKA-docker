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
    DEPTH_SN=$(python3 -c "import yaml; d=yaml.safe_load(open('$SENSORS_YAML')); print(d['single']['depth_camera_serial'])")
    if [ "$DEPTH_SN" = "CHANGE_ME" ]; then
        echo "Warning: depth_camera_serial is not set in config/sensors.yaml"
    fi
else
    L_SN=$(python3 -c "import yaml; d=yaml.safe_load(open('$SENSORS_YAML')); print(d['multi']['left_depth_camera_serial'])")
    R_SN=$(python3 -c "import yaml; d=yaml.safe_load(open('$SENSORS_YAML')); print(d['multi']['right_depth_camera_serial'])")
    if [ "$L_SN" = "CHANGE_ME" ] || [ "$R_SN" = "CHANGE_ME" ]; then
        echo "Warning: one or more serial numbers are not set in config/sensors.yaml"
    fi
fi

# Remove any existing container with the same name
docker rm -f "$CONTAINER_NAME" 2>/dev/null && echo "Removed existing container: $CONTAINER_NAME" || true

# Allow Docker to connect to the host X11 display (required for RViz)
xhost +local:docker

# Build docker run arguments
DOCKER_ARGS=(
    -it --rm
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
        -v "$SCRIPT_DIR/config/start_multi_sensor.bash:/root/pika_ros/install/share/sensor_tools/scripts/start_multi_sensor.bash"
    )
fi

echo "Starting container in $MODE mode..."
docker run "${DOCKER_ARGS[@]}" "$IMAGE"
