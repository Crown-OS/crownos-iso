FROM docker.io/archlinux/archlinux:base-devel

RUN pacman -Syu --noconfirm --needed \
      git clang pkgconf cmake curl gnupg \
      wayland libxkbcommon libinput seatd systemd-libs mesa libglvnd pixman \
      fontconfig freetype2 vulkan-icd-loader alsa-lib dbus pipewire ffmpeg opus \
      libdrm openssl \
 && pacman -Scc --noconfirm

ARG RUST_VERSION=1.97.1
ARG NFPM_VERSION=2.47.0
ENV RUSTUP_HOME=/opt/rustup CARGO_HOME=/opt/cargo PATH=/opt/cargo/bin:$PATH
RUN curl -fsSL https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain "$RUST_VERSION" \
 && curl -fsSL "https://github.com/goreleaser/nfpm/releases/download/v${NFPM_VERSION}/nfpm_${NFPM_VERSION}_Linux_x86_64.tar.gz" \
    | tar -xz -C /usr/local/bin nfpm
