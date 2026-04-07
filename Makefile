IMAGE := pika-ros

build:
	docker build -t $(IMAGE) .

# Before running, apply the VIVE tracker udev rules on the host:
#   sudo cp <path-to-pika_ros>/scripts/81-vive.rules /etc/udev/rules.d/
#   sudo udevadm control --reload-rules && sudo udevadm trigger
#   Then replug the USB receiver.
run:
	docker run --rm -it --privileged -v /dev:/dev $(IMAGE)

.PHONY: build run
