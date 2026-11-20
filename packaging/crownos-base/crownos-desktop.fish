# Signing in on tty1 runs the per-user agent setup, then opens the desktop.
# Leaving it signs out; if it fails to start, the shell stays so the user can
# see why.
if status is-login; and test (tty) = /dev/tty1; and not set -q WAYLAND_DISPLAY; and test (id -u) -ne 0
    if command -q crownos-setup
        crownos-setup user
    else if command -q crownos-agent-skills
        crownos-agent-skills
    end
    crownos-desktop; and exit
end
