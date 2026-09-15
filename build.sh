#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Build the CrownOS ISO. Works on Arch natively and on every other distribution
# through a privileged Arch container, so "you need an Arch box to build the
# image" stops being true.
#
#   ./build.sh                 # native if this is Arch, container otherwise
#   ./build.sh --container     # force the container even on Arch
#   ./build.sh --native        # force native; fails loudly if unusable
#   ./build.sh --check         # report what this machine can do, build nothing
#   ./build.sh --out DIR       # default ./out
#   ./build.sh --work DIR      # default ./work

set -euo pipefail

# Assigned before `readonly`, not with it: in `readonly X="$(cmd)"` the exit
# status belongs to readonly, not to cmd, so a failing cd would pass silently
# even under `set -e`.
PROFILE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROFILE_DIR
readonly IMAGE="${CROWNOS_ISO_IMAGE:-docker.io/library/archlinux:latest}"
readonly MIN_FREE_GB=12

OUT_DIR="$PROFILE_DIR/out"
WORK_DIR="$PROFILE_DIR/work"
MODE=auto

die()  { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }
note() { printf '\033[36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[33mwarning:\033[0m %s\n' "$*" >&2; }

usage() { sed -n '3,14p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'; exit 0; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --container) MODE=container ;;
    --native)    MODE=native ;;
    --check)     MODE=check ;;
    --out)       OUT_DIR="${2:?--out needs a directory}"; shift ;;
    --work)      WORK_DIR="${2:?--work needs a directory}"; shift ;;
    -h|--help)   usage ;;
    *)           die "unknown argument: $1 (try --help)" ;;
  esac
  shift
done

have() { command -v "$1" >/dev/null 2>&1; }

container_runtime() {
  # podman first: it is the one that does not need a daemon, and rootful podman
  # is what CI uses.
  for rt in podman docker; do have "$rt" && { printf '%s' "$rt"; return 0; }; done
  return 1
}

free_gb() { df -BG --output=avail "$1" 2>/dev/null | tail -1 | tr -dc '0-9'; }

check_space() {
  local target="$1" avail
  mkdir -p "$target"
  avail="$(free_gb "$target")"
  [[ -z "$avail" ]] && return 0
  (( avail < MIN_FREE_GB )) &&
    warn "only ${avail}G free at $target; a full build needs about ${MIN_FREE_GB}G"
  return 0
}

report() {
  local rt
  echo "profile:        $PROFILE_DIR"
  # /etc/os-release exists only on the host at run time, so there is no file
  # here to analyse. The sourcing happens inside a command substitution, so the
  # variables it sets cannot leak into this script.
  # shellcheck source=/dev/null
  echo "host distro:    $( [[ -r /etc/os-release ]] && . /etc/os-release && echo "${PRETTY_NAME:-$ID}" || echo unknown )"
  echo "mkarchiso:      $(have mkarchiso && command -v mkarchiso || echo 'not installed')"
  echo "pacman:         $(have pacman && command -v pacman || echo 'not installed')"
  rt="$(container_runtime || true)"
  echo "container:      ${rt:-none found (install podman or docker)}"
  echo "free space:     $(free_gb "$PROFILE_DIR" || echo '?')G at $PROFILE_DIR (need ~${MIN_FREE_GB}G)"
  echo "loop devices:   $( [[ -e /dev/loop-control ]] && echo present || echo 'MISSING -- mkarchiso cannot work' )"
  echo
  if have mkarchiso; then
    echo "This machine can build natively:  sudo ./build.sh --native"
  elif [[ -n "${rt:-}" ]]; then
    echo "This machine can build in a container:  ./build.sh --container"
  else
    echo "This machine cannot build yet. Install 'archiso' (on Arch) or podman/docker."
  fi
}

build_native() {
  have mkarchiso || die "mkarchiso not found. On Arch: sudo pacman -S archiso"
  [[ $EUID -eq 0 ]] || die "mkarchiso needs root. Re-run: sudo $0 --native"
  check_space "$WORK_DIR"
  note "building natively into $OUT_DIR"
  mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$PROFILE_DIR"
}

build_container() {
  local rt; rt="$(container_runtime)" || die \
    "no container runtime. Install podman (recommended) or docker, or build on Arch with --native."
  check_space "$WORK_DIR"
  note "building in $rt using $IMAGE"
  # --privileged: mkarchiso needs loop devices and mount(2). This is the reason
  # a plain unprivileged container cannot do it.
  "$rt" run --rm --privileged \
    -v "$PROFILE_DIR:/profile:Z" \
    -v "$OUT_DIR:/out:Z" \
    -v "$WORK_DIR:/work:Z" \
    "$IMAGE" \
    bash -euo pipefail -c '
      pacman -Sy --noconfirm --needed archiso
      mkarchiso -v -w /work -o /out /profile
    '
}

mkdir -p "$OUT_DIR" "$WORK_DIR"

case "$MODE" in
  check)     report ;;
  native)    build_native ;;
  container) build_container ;;
  auto)
    if have mkarchiso && [[ $EUID -eq 0 ]]; then build_native
    elif container_runtime >/dev/null;          then build_container
    else
      report; echo
      die "nothing on this machine can build the ISO yet -- see above"
    fi
    ;;
esac

[[ "$MODE" == check ]] || {
  note "done"
  ls -lh "$OUT_DIR"/*.iso 2>/dev/null || warn "no .iso in $OUT_DIR"
}
