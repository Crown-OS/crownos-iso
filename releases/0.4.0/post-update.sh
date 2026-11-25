#!/usr/bin/env bash
# CrownOS 0.4.0 replaces the wallpapers. A user whose wallpaper was removed
# gets the new default wallpaper. The edit runs as the user, so a link in a
# home cannot make root write a system file.

set -euo pipefail

backgrounds=/usr/share/backgrounds/crownos
default_wallpaper=$backgrounds/amber-eclipse.jpg
wallpaper_line='^([[:space:](]*wallpaper:[[:space:]]*)"([^"]*)"'

replace_removed_wallpaper() {
    local user=$1 appearance=$2 wallpaper
    wallpaper=$(runuser -u "$user" -- sed -nE "s#$wallpaper_line.*#\\2#p" "$appearance" | head -n 1)
    [[ $wallpaper == "$backgrounds"/* && ! -e $wallpaper ]] || return 0
    runuser -u "$user" -- sed -i -E "s#$wallpaper_line#\\1\"$default_wallpaper\"#" "$appearance"
}

while IFS=: read -r user _ uid _ _ home _; do
    ((uid >= 1000 && uid < 60000)) || continue
    appearance=$home/.config/crownos/appearance.ron
    [[ -f $appearance ]] || continue
    replace_removed_wallpaper "$user" "$appearance" ||
        echo "post-update: cannot set the default wallpaper for $user" >&2
done < <(getent passwd)
