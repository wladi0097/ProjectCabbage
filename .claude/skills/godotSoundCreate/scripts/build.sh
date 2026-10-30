#!/usr/bin/env bash
set -euo pipefail
if [ $# -lt 2 ]; then
	echo 'usage: build.sh <takes dir> '\''sound <name> "<length> <fade> [peak]" <take> <label> "<start> <gain> [cut]" ...'\'' ...'
	exit 1
fi
TAKES=$1
shift
SRC="$(cd "$(dirname "$0")/../../../.." && pwd)/assets/audio/sources"

sound() {
	local name=$1 header=$2
	shift 2
	rm -f "$SRC/$name"/*.wav
	mkdir -p "$SRC/$name"
	echo "length $header" > "$SRC/$name/layers"
	local n=1
	while [ $# -gt 0 ]; do
		local take=$1 label=$2 rest=$3
		shift 3
		cp "$TAKES/$take.wav" "$SRC/$name/${n}_$label.wav"
		echo "${n}_$label.wav $rest" >> "$SRC/$name/layers"
		n=$((n + 1))
	done
	bash "$SRC/mix.sh" "$name"
}

for spec in "$@"; do
	eval "$spec"
done
