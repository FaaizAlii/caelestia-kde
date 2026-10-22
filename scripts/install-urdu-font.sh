#!/usr/bin/env bash
set -euo pipefail
[[ $EUID -ne 0 ]] || { echo 'Run without sudo.' >&2; exit 1; }
font_dir="$HOME/.local/share/fonts/caelestia"
font_file="$font_dir/Jameel Noori Nastaleeq.ttf"
if [[ -f "$font_file" ]] && fc-scan --format '%{family}' "$font_file" | rg -q 'Jameel Noori Nastaleeq'; then
    printf '%s\n' "$font_file"
    exit 0
fi
temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT
# This is the versioned archive and checksum used by the font's Arch installer.
url=https://github.com/abid-mujtaba/ttf-jameel-noori-nastaleeq/archive/refs/tags/v1.1.0.tar.gz
echo 'Downloading Jameel Noori Nastaleeq...' >&2
if curl -fL --retry 2 --connect-timeout 15 --max-time 120 "$url" -o "$temp_dir/font.tar.gz" \
    && printf '%s  %s\n' b45b88700e74483115d1f12ff69e0688 "$temp_dir/font.tar.gz" | md5sum -c --status \
    && tar -xOf "$temp_dir/font.tar.gz" 'ttf-jameel-noori-nastaleeq-1.1.0/Jameel Noori Nastaleeq.ttf' > "$temp_dir/font.ttf" \
    && fc-scan --format '%{family}' "$temp_dir/font.ttf" | rg -q 'Jameel Noori Nastaleeq'; then
    mkdir -p "$font_dir"
    install -m 0644 "$temp_dir/font.ttf" "$font_file"
    fc-cache -f "$font_dir" >&2
    echo 'Installed Jameel Noori Nastaleeq for your user account.' >&2
    printf '%s\n' "$font_file"
else
    echo 'The Jameel download could not be verified; using the installed Noto Nastaliq Urdu font.' >&2
    family="$(fc-match -f '%{family}' 'Noto Nastaliq Urdu')"
    [[ "$family" == *'Noto Nastaliq Urdu'* ]] || { echo 'No Nastaliq font is available.' >&2; exit 1; }
    fc-match -f '%{file}\n' 'Noto Nastaliq Urdu'
fi
