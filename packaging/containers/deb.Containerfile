# Debian and Ubuntu share this file: build with --build-arg BASE=ubuntu:26.04.
ARG BASE=debian:trixie
FROM docker.io/library/${BASE}

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential ca-certificates curl git clang libclang-dev pkg-config cmake gnupg apt-utils \
      libwayland-dev libxkbcommon-dev libinput-dev libseat-dev libudev-dev libgbm-dev libegl-dev \
      libgles-dev libpixman-1-dev libfontconfig-dev libfreetype-dev libvulkan-dev libasound2-dev \
      libdbus-1-dev libpipewire-0.3-dev libavcodec-dev libavformat-dev libavfilter-dev \
      libavutil-dev libavdevice-dev libswscale-dev libswresample-dev libopus-dev libdrm-dev libssl-dev \
 && rm -rf /var/lib/apt/lists/*

ARG RUST_VERSION=1.97.1
ARG NFPM_VERSION=2.47.0
ENV RUSTUP_HOME=/opt/rustup CARGO_HOME=/opt/cargo PATH=/opt/cargo/bin:$PATH
RUN curl -fsSL https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain "$RUST_VERSION" \
 && curl -fsSL "https://github.com/goreleaser/nfpm/releases/download/v${NFPM_VERSION}/nfpm_${NFPM_VERSION}_Linux_x86_64.tar.gz" \
    | tar -xz -C /usr/local/bin nfpm
