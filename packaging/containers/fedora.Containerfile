FROM registry.fedoraproject.org/fedora:44

# ffmpeg-free carries the patent-unencumbered codecs only; H.264 in
# crownconnect needs RPM Fusion's ffmpeg on the installed system.
RUN dnf -y install \
      gcc gcc-c++ make git clang clang-devel pkgconf-pkg-config cmake curl gnupg2 createrepo_c \
      wayland-devel libxkbcommon-devel libinput-devel libseat-devel systemd-devel mesa-libgbm-devel \
      mesa-libEGL-devel mesa-libGLES-devel pixman-devel fontconfig-devel freetype-devel \
      vulkan-loader-devel alsa-lib-devel dbus-devel pipewire-devel ffmpeg-free-devel opus-devel \
      libdrm-devel openssl-devel \
 && dnf clean all

ARG RUST_VERSION=1.97.1
ARG NFPM_VERSION=2.47.0
ENV RUSTUP_HOME=/opt/rustup CARGO_HOME=/opt/cargo PATH=/opt/cargo/bin:$PATH
RUN curl -fsSL https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain "$RUST_VERSION" \
 && curl -fsSL "https://github.com/goreleaser/nfpm/releases/download/v${NFPM_VERSION}/nfpm_${NFPM_VERSION}_Linux_x86_64.tar.gz" \
    | tar -xz -C /usr/local/bin nfpm
