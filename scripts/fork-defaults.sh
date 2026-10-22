#!/usr/bin/env bash
# Restore the personal additions as part of normal source installation and updates.
set -euo pipefail
repo="${BUNDLE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
font_file="$(bash "$repo/scripts/install-urdu-font.sh")"
python3 - "$font_file" <<'PY'
import json, os, sys
from pathlib import Path
path = Path.home() / '.config/caelestia/shell.json'
path.parent.mkdir(parents=True, exist_ok=True)
config = json.loads(path.read_text()) if path.exists() else {}
services = config.setdefault('services', {})
services.setdefault('romanizeIndicLyrics', True)
services.setdefault('urduFontFile', Path(sys.argv[1]).as_uri())
temp = path.with_name(path.name + '.fork.tmp')
temp.write_text(json.dumps(config, indent=4, ensure_ascii=False) + '\n')
os.chmod(temp, path.stat().st_mode & 0o777 if path.exists() else 0o600)
temp.replace(path)
PY
mkdir -p "$HOME/.config/quickshell/caelestia"
printf 'main\n' > "$HOME/.config/quickshell/caelestia/.update_branch"
scripts_dir="${XDG_DATA_HOME:-$HOME/.local/share}/kwin/scripts"
mkdir -p "$scripts_dir/three-finger-overview-sensitive"
cp -a "$repo/src/kwin/scripts/three-finger-overview-sensitive/." "$scripts_dir/three-finger-overview-sensitive/"
kwriteconfig6 --file kwinrc --group Plugins --key three-finger-overviewEnabled false
kwriteconfig6 --file kwinrc --group Plugins --key three-finger-overview-sensitiveEnabled true
if command -v qdbus6 >/dev/null 2>&1; then
    qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
    qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.start >/dev/null 2>&1 || true
fi
printf '%s\n' 'Personal language defaults and short swipe Overview gestures installed.'
