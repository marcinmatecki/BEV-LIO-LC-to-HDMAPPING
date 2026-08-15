FROM nvidia/cuda:12.8.0-cudnn-devel-ubuntu20.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Warsaw

SHELL ["/bin/bash", "-c"]

ENV CUDA_HOME=/usr/local/cuda
ENV PATH=/usr/local/cuda/bin:${PATH}
ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64:${LD_LIBRARY_PATH}

RUN apt-get update && apt-get install -y \
    tzdata \
    locales \
    lsb-release \
    gnupg2 \
    curl \
    wget \
    git \
    nlohmann-json3-dev \
    sudo \
    vim \
    nano \
    tmux \
    unzip \
    zip \
    build-essential \
    cmake \
    pkg-config \
    python3 \
    python3-pip \
    python3-dev \
    gcc-9 \
    g++-9 \
    libeigen3-dev \
    libpcl-dev \
    libboost-all-dev \
    libgoogle-glog-dev \
    libgflags-dev \
    libyaml-cpp-dev \
    libtbb-dev \
    libomp-dev \
    libceres-dev \
    libsuitesparse-dev \
    libgtk2.0-dev \
    libavcodec-dev \
    libavformat-dev \
    libswscale-dev \
    libjpeg-dev \
    libpng-dev \
    libtiff-dev \
    libdc1394-22-dev \
    && rm -rf /var/lib/apt/lists/*

ENV CC=/usr/bin/gcc-9
ENV CXX=/usr/bin/g++-9

RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-9 90 && \
    update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-9 90

RUN gcc --version && \
    g++ --version

RUN locale-gen en_US.UTF-8

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

RUN echo "deb http://packages.ros.org/ros/ubuntu focal main" \
    > /etc/apt/sources.list.d/ros1.list

RUN curl -fsSL \
    https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
    | apt-key add -

RUN apt-get update && apt-get install -y \
    ros-noetic-desktop-full \
    python3-rosdep \
    python3-catkin-tools \
    python3-rosinstall \
    python3-rosinstall-generator \
    python3-wstool \
    && rm -rf /var/lib/apt/lists/*

RUN rosdep init || true
RUN rosdep update

ENV ROS_DISTRO=noetic

WORKDIR /workspace

RUN mkdir -p /workspace

RUN git clone \
    https://github.com/borglab/gtsam.git \
    /workspace/gtsam

WORKDIR /workspace/gtsam

RUN git checkout 4.0.0-alpha2

RUN mkdir -p build && \
    cd build && \
    cmake .. \
        -DGTSAM_BUILD_WITH_MKLDNN=OFF \
        -DGTSAM_BUILD_WITH_MKL=OFF \
        -DGTSAM_BUILD_TESTS=OFF \
        -DGTSAM_BUILD_EXAMPLES_ALWAYS=OFF \
        -DGTSAM_BUILD_UNSTABLE=OFF \
        -DGTSAM_USE_SYSTEM_EIGEN=ON \
        -DCMAKE_BUILD_TYPE=Release && \
    make -j"$(nproc)" && \
    make install && \
    ldconfig

WORKDIR /workspace

RUN git clone https://github.com/Livox-SDK/Livox-SDK.git /workspace/Livox-SDK && \
    cd /workspace/Livox-SDK && \
    mkdir -p build && \
    cd build && \
    cmake .. && \
    make -j$(nproc) && \
    make install && \
    ldconfig

WORKDIR /workspace

RUN wget -q \
    "https://download.pytorch.org/libtorch/cu128/libtorch-cxx11-abi-shared-with-deps-2.7.1%2Bcu128.zip" \
    -O /tmp/libtorch.zip && \
    unzip -q /tmp/libtorch.zip -d /workspace && \
    rm -f /tmp/libtorch.zip

ENV LIBTORCH=/workspace/libtorch
ENV Torch_DIR=/workspace/libtorch/share/cmake/Torch

ENV LD_LIBRARY_PATH=/workspace/libtorch/lib:/usr/local/cuda/lib64:${LD_LIBRARY_PATH}

RUN echo "===== CUDA =====" && \
    nvcc --version

RUN echo "===== LIBTORCH =====" && \
    test -f /workspace/libtorch/share/cmake/Torch/TorchConfig.cmake && \
    test -f /workspace/libtorch/lib/libtorch.so && \
    ls -lh /workspace/libtorch/lib/libtorch.so

WORKDIR /workspace

RUN git clone \
    --branch 4.2.0 \
    --depth 1 \
    https://github.com/opencv/opencv.git \
    /workspace/opencv

RUN git clone \
    --branch 4.2.0 \
    --depth 1 \
    https://github.com/opencv/opencv_contrib.git \
    /workspace/opencv_contrib

WORKDIR /workspace/opencv

RUN mkdir -p build

WORKDIR /workspace/opencv/build

RUN cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DOPENCV_EXTRA_MODULES_PATH=/workspace/opencv_contrib/modules \
    -DOPENCV_ENABLE_NONFREE=ON \
    -DBUILD_TESTS=OFF \
    -DBUILD_PERF_TESTS=OFF \
    -DBUILD_EXAMPLES=OFF \
    -DBUILD_opencv_python3=OFF \
    ..

RUN make -j"$(nproc)"

RUN make install

RUN ldconfig

RUN echo "===== OPENCV =====" && \
    /usr/local/bin/opencv_version

RUN echo "===== XFEATURES2D =====" && \
    test -f /usr/local/include/opencv4/opencv2/xfeatures2d.hpp && \
    test -f /usr/local/lib/libopencv_xfeatures2d.so && \
    echo "xfeatures2d OK"

ENV OpenCV_DIR=/usr/local/lib/cmake/opencv4

ENV LD_LIBRARY_PATH=/usr/local/lib:/workspace/libtorch/lib:/usr/local/cuda/lib64:${LD_LIBRARY_PATH}

WORKDIR /workspace/benchmark

COPY src /workspace/benchmark/src

RUN python3 - <<'PY'
from pathlib import Path

path = Path(
    "/workspace/libtorch/include/torch/csrc/api/include/torch/nn/options/vision.h"
)

text = path.read_text()

old = (
    "typedef std::variant<"
    "enumtype::kBilinear, "
    "enumtype::kNearest> mode_t;"
)

new = (
    "typedef std::variant<"
    "enumtype::kBilinear, "
    "enumtype::kNearest, "
    "enumtype::kBicubic> mode_t;"
)

if old in text:
    path.write_text(text.replace(old, new))
    print("LibTorch vision.h patched successfully.")

elif "enumtype::kBicubic" in text:
    print("LibTorch already contains kBicubic.")

else:
    raise RuntimeError(
        "Could not locate expected mode_t definition."
    )
PY

RUN grep -n -A8 -B3 "mode_t" \
    /workspace/libtorch/include/torch/csrc/api/include/torch/nn/options/vision.h

RUN source /opt/ros/noetic/setup.bash && \
    cd /workspace/benchmark && \
    rosdep install \
        --from-paths src \
        --ignore-src \
        --rosdistro noetic \
        -r -y

WORKDIR /workspace/benchmark

RUN sed -i \
    's|lid_topic:  "points_raw"|lid_topic:  "/velodyne_points"|' \
    src/BEV-LIO-LC/config/velodyne.yaml

RUN sed -i \
    's|imu_topic:  "imu_raw"|imu_topic:  "/imu/data"|' \
    src/BEV-LIO-LC/config/velodyne.yaml

RUN sed -i 's|loopClosureEnableFlag: false|loopClosureEnableFlag: true|' src/BEV-LIO-LC/config/velodyne.yaml

RUN source /opt/ros/noetic/setup.bash && \
    cd /workspace/benchmark && \
    catkin_make

ARG UID=1000
ARG GID=1000
RUN groupadd -g $GID ros && \
useradd -m -u $UID -g $GID -s /bin/bash ros

ENV CUDA_HOME=/usr/local/cuda
ENV LIBTORCH=/workspace/libtorch
ENV Torch_DIR=/workspace/libtorch/share/cmake/Torch
ENV OpenCV_DIR=/usr/local/lib/cmake/opencv4
ENV ROS_DISTRO=noetic

ENV PATH=/usr/local/cuda/bin:${PATH}

ENV LD_LIBRARY_PATH=/usr/local/lib:/workspace/libtorch/lib:/usr/local/cuda/lib64:${LD_LIBRARY_PATH}

RUN echo "source /opt/ros/noetic/setup.bash" \
    >> /root/.bashrc

RUN echo "source /workspace/benchmark/devel/setup.bash" \
    >> /root/.bashrc

RUN echo "export CUDA_HOME=/usr/local/cuda" \
    >> /root/.bashrc

RUN echo "export LIBTORCH=/workspace/libtorch" \
    >> /root/.bashrc

RUN echo "export Torch_DIR=/workspace/libtorch/share/cmake/Torch" \
    >> /root/.bashrc

RUN echo "export OpenCV_DIR=/usr/local/lib/cmake/opencv4" \
    >> /root/.bashrc

RUN echo "export PATH=/usr/local/cuda/bin:\$PATH" \
    >> /root/.bashrc

RUN echo "export LD_LIBRARY_PATH=/usr/local/lib:/workspace/libtorch/lib:/usr/local/cuda/lib64:\$LD_LIBRARY_PATH" \
    >> /root/.bashrc

WORKDIR /workspace/benchmark

CMD ["/bin/bash"]
