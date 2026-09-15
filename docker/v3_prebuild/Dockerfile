ARG UHD_VERSION=v4.7
# ランタイム段のベースは、UHDイメージのUbuntuバージョンに合わせること
ARG RUNTIME_IMAGE=ubuntu:24.04
FROM ghcr.io/k3komatsu/uhd:${UHD_VERSION} AS builder
# LDC 1.40以前はlibxml2.so.2を要求し、Ubuntu 26.04(UHD v4.10以降)では起動できない
ARG LDC_VERSION=1.39.0

WORKDIR /work

# clangが選ぶGCCと、入っているlibstdc++ヘッダのバージョンがずれている環境があるため揃える
# (Ubuntu 26.04のclang 21はGCC 16を選ぶが、libstdc++-16-devは未導入。24.04では何もしない)
RUN <<'EOF'
    set -e
    gccdir=$(clang++ -v -E -x c++ /dev/null -o /dev/null 2>&1 | sed -n 's|.*Selected GCC installation: .*/||p')
    if [ -n "$gccdir" ] && [ ! -d "/usr/include/c++/$gccdir" ]; then
        apt-get update
        DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "libstdc++-$gccdir-dev"
        rm -rf /var/lib/apt/lists/*
    fi
EOF

# install bladeRF
RUN <<EOF
    set -e
    cd ~
    mkdir -p tmp
    cd tmp
    git clone -b 2023.02 https://github.com/Nuand/bladeRF.git ./bladeRF
    cd bladeRF/host
    mkdir build
    cd build
    # CMake 4はcmake_minimum_required<3.5を拒否し、GCC 15は-Werrorで落ちる(Ubuntu 26.04)
    cmake -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DTREAT_WARNINGS_AS_ERRORS=OFF -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local -DINSTALL_UDEV_RULES=ON -DBLADERF_GROUP=root ../
    make
    make install
    ldconfig
    cd /opt
    # mkdir bladeRF
    # cd bladeRF
    # wget https://www.nuand.com/fx3/bladeRF_fw_v2.4.0.img
    # wget https://www.nuand.com/fpga/v0.15.3/hostedxA4.rbf
    # wget https://www.nuand.com/fpga/v0.15.3/hostedxA5.rbf
    # wget https://www.nuand.com/fpga/v0.15.3/hostedxA9.rbf
    # wget https://www.nuand.com/fpga/v0.15.3/hostedx40.rbf
    # wget https://www.nuand.com/fpga/v0.15.3/hostedx115.rbf
EOF

# install HackRF One
RUN <<EOF
    set -e
    cd ~
    mkdir -p tmp
    cd tmp
    wget https://github.com/greatscottgadgets/hackrf/releases/download/v2024.02.1/hackrf-2024.02.1.tar.xz
    tar -xf hackrf-2024.02.1.tar.xz
    cd hackrf-2024.02.1/host
    mkdir build
    cd build
    cmake -DCMAKE_POLICY_VERSION_MINIMUM=3.5 ..
    make
    make install
    ldconfig
EOF

# install ldc
RUN <<EOF
    set -e
    cd /
    mkdir -p /dlang && wget https://dlang.org/install.sh -O /dlang/install.sh
    chmod +x /dlang/install.sh
    /dlang/install.sh install -p /dlang ldc-${LDC_VERSION}
    echo 'source /dlang/ldc-${LDC_VERSION}/activate' >> /root/.bashrc
EOF

# copy all files from the current directory to the container /work directory
COPY . .

RUN <<EOF
    set -e
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib
    source /dlang/ldc-${LDC_VERSION}/activate
    cd /work
    dub test
    dub build --build=release
    cp /work/ezsdr /usr/bin
EOF

RUN <<'EOF'
    set -e
    mkdir -p /bundle
    cp -r --parents /usr/bin/ezsdr /bundle
    # ezsdrが必要とする共有ライブラリを再帰的に集める。
    # UHDのバージョンによってUbuntu・Boost・Pythonのバージョンが変わり、
    # ライブラリ名も変わる(例: 26.04ではlibboost_systemが消えlibpythonは3.14)ため直書きしない。
    ldd /usr/bin/ezsdr | awk '$2 == "=>" && $3 ~ /^\// { print $3 }' | sort -u | while read -r lib; do
        cp -L -r --parents "$lib" /bundle
    done
EOF

RUN cp /work/client/*.py /bundle

FROM ${RUNTIME_IMAGE}
COPY --from=builder /bundle /bundle
COPY docker/v3_prebuild/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
# COPY --from=0 /opt/bladeRF /opt/bladeRF
ENV LD_LIBRARY_PATH=/bundle/lib/x86_64-linux-gnu:/bundle/usr/lib/x86_64-linux-gnu:/bundle/usr/local/lib
WORKDIR /work
ENTRYPOINT ["/entrypoint.sh"]
