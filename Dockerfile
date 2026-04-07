FROM ros:noetic-ros-base

ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies (manual §2.4, step 3)
RUN apt-get update && apt-get install -y \
    libjsoncpp-dev \
    ros-noetic-ddynamic-reconfigure \
    libpcap-dev \
    ros-noetic-serial \
    ros-noetic-ros-numpy \
    python3-pcl \
    libqt5serialport5-dev \
    build-essential \
    zlib1g-dev \
    libx11-dev \
    libusb-1.0-0-dev \
    freeglut3-dev \
    liblapacke-dev \
    libopenblas-dev \
    libatlas-base-dev \
    cmake \
    git \
    libssl-dev \
    pkg-config \
    libgtk-3-dev \
    libglfw3-dev \
    libgl1-mesa-dev \
    libglu1-mesa-dev \
    g++ \
    python3-pip \
    libopenvr-dev \
    unzip \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install opencv-python

# Clone pika_ros (manual §2.4, step 2)
WORKDIR /root
RUN git clone https://github.com/agilexrobotics/pika_ros.git

# Install USB udev rules (manual §2.4, step 4)
# udevadm reload cannot run during Docker build; apply on the host before running the container:
#   sudo cp pika_ros/scripts/81-vive.rules /etc/udev/rules.d/
#   sudo udevadm control --reload-rules && sudo udevadm trigger
RUN mkdir -p /etc/udev/rules.d/ && cp /root/pika_ros/scripts/81-vive.rules /etc/udev/rules.d/

# Build librealsense 2.55.1 from source bundled in pika_ros/source/ (manual §2.4, step 5)
WORKDIR /root/pika_ros/source
RUN unzip librealsense-2.55.1.zip && tar -xzf curl-7.75.0.tar.gz


WORKDIR /root/pika_ros/source/librealsense
RUN sed -i \
    's|URL "/home/agilex/curl-7.75.0"|URL "/root/pika_ros/source/curl-7.75.0"|g' \
    CMake/external_libcurl.cmake
RUN bash install.bash

# Extract the pre-built pika_ros install tree (manual §2.4, step 6)
WORKDIR /root/pika_ros/source
RUN unzip install.zip -d /root/pika_ros/ && chmod 777 -R /root/pika_ros/install/

# Source ROS environments on login (manual §2.4, step 7)
RUN echo 'source /opt/ros/noetic/setup.bash' >> /root/.bashrc && \
    echo 'source /root/pika_ros/install/setup.bash' >> /root/.bashrc

# Entrypoint ensures ROS env is active for both interactive shells and exec invocations
RUN printf '#!/bin/bash\nsource /opt/ros/noetic/setup.bash\nsource /root/pika_ros/install/setup.bash\nexec "$@"\n' \
    > /ros_entrypoint.sh && chmod +x /ros_entrypoint.sh

ENTRYPOINT ["/ros_entrypoint.sh"]
CMD ["bash"]
