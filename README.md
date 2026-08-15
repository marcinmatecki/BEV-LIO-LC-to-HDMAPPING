# BEV-LIO-LC to HDMapping simplified instruction

## Step 1 (prepare data)

Download `kitti_seq00_ros1.bag` from [kitti_to_ros](https://github.com/Jakubach/kitti_to_ros).

```shell
mkdir -p ~/hdmapping-benchmark-loop-closure/data
cd ~/hdmapping-benchmark-loop-closure/data
```

The dataset should be located in:

```text
~/hdmapping-benchmark-loop-closure/data/kitti_seq00_ros1.bag
```

## Step 2 (prepare docker)

```shell
cd ~/hdmapping-benchmark-loop-closure
git clone https://github.com/marcinmatecki/BEV-LIO-LC-to-HDMAPPING --recursive
cd BEV-LIO-LC-to-HDMAPPING
docker build -t bev-lio-lc .
```

## Step 3 (run docker)

```shell
cd ~/hdmapping-benchmark-loop-closure/BEV-LIO-LC-to-HDMAPPING
chmod +x docker_session_run-ros1-bev-lio-lc.sh
cd ~/hdmapping-benchmark-loop-closure/data
~/hdmapping-benchmark-loop-closure/BEV-LIO-LC-to-HDMAPPING/docker_session_run-ros1-bev-lio-lc.sh kitti_seq00_ros1.bag .
```

## Step 4 (Open and visualize data)

Output should appear in:

```text
~/hdmapping-benchmark-loop-closure/data/output_hdmapping-bev-lio-lc
```

Open `session.json` using [multi_view_tls_registration_step_2](https://github.com/MapsHD/HDMapping).

Expected files:

```text
lio_initial_poses.reg
poses.reg
scan_lio_*.laz
session.json
trajectory_lio_*.csv
```