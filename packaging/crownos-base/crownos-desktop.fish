# Signing in on tty1 opens the desktop. Leaving it signs out; if it fails to
# start, the shell stays so the user can see why.
if status is-login; and test (tty) = /dev/tty1; and not set -q WAYLAND_DISPLAY; and test (id -u) -ne 0
    crownos-desktop; and exit
end
