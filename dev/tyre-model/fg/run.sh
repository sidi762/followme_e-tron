#!/bin/bash
# Drive the car through a scripted run in a real FlightGear, without a display.
#
#   dev/tyre-model/fg/run.sh [aircraft] [script]
#
#   aircraft  followme_e-tron-tyre (default), followme_e-tron, ...
#   script    drive.nas (default): start, accelerate, brake, turn, lock up, reverse
#             reposition.nas: reposition while moving and with the engine off
#
# This is the only check that runs the Nasal side. It needs fgfs and xvfb-run
# (Debian/Ubuntu: apt install flightgear xvfb) and renders in software, so
# expect a few frames per second. Set FGFS or FG_ROOT if they live elsewhere.
#
# Prints the result lines and exits non-zero if the script did not finish or
# FlightGear logged a Nasal error.
set -u

here="$(cd "$(dirname "$0")" && pwd)"
aircraft_dir="$(cd "$here/../../.." && pwd)"
aircraft="${1:-followme_e-tron-tyre}"
script="$here/${2:-drive.nas}"
fgfs="${FGFS:-$(command -v fgfs || echo /usr/games/fgfs)}"
fg_root="${FG_ROOT:-/usr/share/games/flightgear}"

# The aircraft refers to its own files as Aircraft/followme_e-tron/...
if [ "$(basename "$aircraft_dir")" != "followme_e-tron" ]; then
	echo "the checkout must be in a folder called followme_e-tron, not $(basename "$aircraft_dir")" >&2
	exit 2
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
log="$work/fgfs.log"
mkdir -p "$work/home" "$work/fghome" "$work/xdg"
chmod 700 "$work/xdg"

# DBUS_FATAL_WARNINGS: without a session bus FlightGear's D-Bus calls would abort it
HOME="$work/home" FG_HOME="$work/fghome" XDG_RUNTIME_DIR="$work/xdg" \
LIBGL_ALWAYS_SOFTWARE=1 DBUS_FATAL_WARNINGS=0 \
timeout 1500 xvfb-run -a -s "-screen 0 640x480x24" "$fgfs" \
	--fg-root="$fg_root" \
	--fg-aircraft="$(dirname "$aircraft_dir")" \
	--aircraft="$aircraft" \
	--airport=BIKF --runway=10 \
	--disable-terrasync --disable-sound --disable-real-weather-fetch \
	--disable-ai-models --disable-ai-traffic --disable-random-objects \
	--disable-clouds --disable-clouds3d --disable-splash-screen --disable-hud \
	--timeofday=noon --geometry=320x240 --visibility=3000 \
	--prop:/sim/rendering/random-vegetation=false \
	--prop:/sim/rendering/shaders/quality-level=0 \
	--prop:/sim/startup/save-on-exit=false \
	--ignore-autosave \
	--prop:/nasal/tyretest/file="$script" \
	> "$log" 2>&1
status=$?

grep "TYRETEST" "$log" | sed -E 's/^.*TYRETEST //'

failed=0
if ! grep -q "TYRETEST DONE" "$log"; then
	echo "the script did not finish (fgfs exit code $status); last lines of the log:" >&2
	tail -n 15 "$log" >&2
	failed=1
fi
if grep -q -E "Nasal (runtime|parse) error|TYRETEST STEP .* FAILED" "$log"; then
	echo "Nasal errors:" >&2
	grep -E -A3 "Nasal (runtime|parse) error|TYRETEST STEP .* FAILED" "$log" >&2
	failed=1
fi
exit $failed
