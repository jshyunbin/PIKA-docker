<div align="center">

# PIKA-docker

[![CI](https://img.shields.io/github/actions/workflow/status/jshyunbin/PIKA-docker/docker-publish.yml?label=CI)](https://github.com/jshyunbin/PIKA-docker/actions/workflows/docker-publish.yml)
[![Docker Pulls](https://img.shields.io/docker/pulls/jshyunbin/pika-ros)](https://hub.docker.com/r/jshyunbin/pika-ros)
[![Docker Image Size](https://img.shields.io/docker/image-size/jshyunbin/pika-ros/latest)](https://hub.docker.com/r/jshyunbin/pika-ros)

[English](README.md) | [한국어](README.ko.md)

</div>

AgileX PIKA 공간 데이터 수집 시스템을 위한 Docker 기반 ROS Noetic 스택입니다.

## 사전 요구사항

- Docker 20.10+
- Ubuntu 20.04 호스트, i5 9세대 이상, 1TB 이상 저장공간, USB 3.0 × 3 (도킹 스테이션 사용 불가)
- Pika Station 베이스 스테이션 설치 및 전원 켜짐
- SteamVR로 포지셔닝 태그 페어링 완료 (최초 1회)

## 초기 설정

### 1. 클론 및 설정

```bash
git clone https://github.com/jshyunbin/PIKA-docker.git
cd PIKA-docker
```

`config/sensors.yaml`을 머신에 맞는 값으로 수정합니다:
- **RealSense 시리얼 번호** — `realsense-viewer`로 확인 후 좌/우 매칭
- **USB 커널 경로** (다중 장치 모드만 해당) — `bash scripts/find_usb_kernel.bash` 실행 (장치를 하나씩 연결하여 확인)

### 2. 호스트 udev 규칙 설치

```bash
# 모드: single_sensor | single_gripper | multi_sensor | multi_gripper | sensor_gripper
sudo bash setup_host.sh single_sensor

# 스크립트 완료 후 모든 USB 장치를 재연결
```

> `multi_*` 및 `sensor_gripper` 모드는 `config/sensors.yaml`의 `usb_kernels`를 먼저 입력하세요.

### 3. 이미지 받기

```bash
docker pull jshyunbin/pika-ros
# 또는 로컬 빌드: docker build -t jshyunbin/pika-ros .
```

### 4. 컨테이너 시작

```bash
bash start.sh single   # Pika Sense 단일
bash start.sh multi    # Pika Sense 듀얼
```

초기 설정이 완료되면 다음 실행 시 1~3단계를 건너뛸 수 있습니다.

## 재실행 시 빠른 참조

초기 설정 완료 후 대부분의 단계는 유지되므로 생략 가능합니다:

**일반 세션 (설정 완료 상태):**
```bash
bash start.sh [single|multi]   # 기존 컨테이너에 재접속
```
이후 사용 워크플로우 §3 (센서 실행) → §4 (데이터 수집) → §5 (동기화)로 바로 이동하세요.

**베이스 스테이션 이동 후:** 사용 워크플로우 §1 재실행 (재보정).
**USB 장치 교체 후:** 초기 설정 §1 (`sensors.yaml` 수정) → §2 (udev 규칙 재설치) 후 `docker rm pika-ros && bash start.sh`로 컨테이너 재생성.
**Vive 트래커 교체 후:** 사용 워크플로우 §2 재실행 (좌/우 코드 재할당).

---

## 사용 워크플로우

### 1. 포지셔닝 베이스 스테이션 보정

최초 설정 시 또는 스테이션을 이동/추가한 후 컨테이너 내부에서 실행:

```bash
cd ~/pika_ros/install/lib && ./survive-cli --force-calibrate
```

`seed runs` / `error failures 0` 출력을 확인한 후 **Ctrl+C**를 누릅니다.
보정이 멈추면: `rm ~/.config/libsurvive/config.json` 후 재시도.


### 2. 좌/우 손 로케이터 설정

```bash
roslaunch pika_locator get_code.launch
```

좌/우 시리얼 코드를 확인하고 `.bashrc`에 추가합니다:

```bash
echo 'export pika_L_code=LHR-EB902458' >> ~/.bashrc

echo 'export pika_R_code=LHR-FE98B2BE' >> ~/.bashrc
# 환경 변수가 이미 존재하면 직접 수정

source ~/.bashrc
```

정렬 상태를 확인합니다:
```bash
roslaunch pika_locator pika_double_tracker.launch
```

모든 트래커, 카메라, 센서가 정렬되었습니다.

### 3. 센서 실행

> ⚠️ 데이터 수집을 위해 아래 명령어를 별도 터미널에서 실행해야 합니다

```bash
cd ~/pika_ros/install/share/sensor_tools/scripts/

bash start_single_sensor.bash   # 단일
bash start_multi_sensor.bash    # 듀얼
```

데이터 수집 전 RViz에서 TF 프레임이 안정적인지 확인하세요.

### 4. 데이터 수집

```bash
source ~/pika_ros/install/setup.bash
# single pika
roslaunch data_tools run_data_capture.launch type:=single_pika datasetDir:=/home/agilex/data  episodeIndex:=0

# multi pika
roslaunch data_tools run_data_capture.launch type:=multi_pika datasetDir:=/home/agilex/data  episodeIndex:=0
```

**Enter**를 눌러 중지합니다. 데이터는 `datasetDir/episode<N>/` 아래에 저장됩니다:

| 경로 | 형식 | 내용 |
|---|---|---|
| `camera/color/pikaDepthCamera/` | `.jpg` | RGB 프레임 |
| `camera/color/pikaFisheyeCamera/` | `.jpg` | 어안 프레임 |
| `camera/depth/pikaDepthCamera/` | `.png` | 깊이 프레임 |
| `localization/pose/pika/` | `.json` | 6-DOF 포즈 |
| `gripper/encoder/pika/` | `.json` | 그리퍼 엔코더 |

### 5. 데이터 동기화

```bash
source ~/pika_ros/install/setup.bash
# single pika
roslaunch data_tools run_data_sync.launch type:=single_pika datasetDir:=/home/agilex/data episodeIndex:=-1

# multi pika
roslaunch data_tools run_data_sync.launch type:=multi_pika datasetDir:=/home/agilex/data episodeIndex:=-1
```

> `type:=single_pika` 또는 `type:=multi_pika`를 반드시 전달하세요 — 기본값 `aloha`는 크래시가 발생합니다.

### 6. HDF5로 데이터 변환

먼저 PCD 데이터를 변환합니다:
```bash
cd ~/pika_ros/scripts
# single pika
python3 camera_point_cloud_filter.py --datasetDir /home/agilex/data/ --type single_pika

# multi pika
python3 camera_point_cloud_filter.py --datasetDir /home/agilex/data/ --type multi_pika
```

이후 HDF5 형식으로 변환합니다:
```bash
cd ~/pika_ros/scripts
# single pika
python3 data_to_hdf5.py --datasetDir /home/agilex/data/ --type single_pika

# multi pika
python3 data_to_hdf5.py --datasetDir /home/agilex/data/ --type multi_pika
```

## 문제 해결

| 문제 | 해결 방법 |
|---|---|
| USB 장치를 찾을 수 없음 | udev 규칙 설치 확인 후 장치 재연결 |
| 보정이 멈춤 | `rm ~/.config/libsurvive/config.json` 후 재시도 |
| `error failures`가 0이 아님 | 적외선 광원 제거 (햇빛 등); 베이스 스테이션 시야각 확인 |
| 사용 중 TF 흔들림 | 재보정: `cd ~/pika_ros/install/lib && ./survive-cli --force-calibrate` |
| RealSense 미감지 | 컨테이너 내부에서 `rs-enumerate-devices` 실행 |

## 감사의 말

- `scripts/find_usb_kernel.bash` 코드 출처: [JHyoonirl/pika_ros2](https://github.com/JHyoonirl/pika_ros2/blob/main/scripts/find_addr.bash)
