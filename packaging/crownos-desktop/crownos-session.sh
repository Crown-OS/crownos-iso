# Log straight into CrownOS on the first virtual terminal.
if [ -z "${WAYLAND_DISPLAY:-}" ] && [ "${XDG_VTNR:-0}" = 1 ] && command -v crownos-session >/dev/null 2>&1; then
  exec crownos-session
fi
