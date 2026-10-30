#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
sound=$1
raw=$(mktemp --suffix=.wav)
trap 'rm -f "$raw"' EXIT

# Header: length <s> <end fade s> [<peak dB>] [<ffmpeg filter for the mix, e.g. highpass=f=250>]
read -r _ length fade target filter < "$sound/layers"
target=${target:--1}
inputs=()
chains=""
labels=""
i=0
while read -r file start gain cut; do
	trim=""
	if [ -n "${cut:-}" ]; then
		trim=",atrim=0:$cut,afade=t=out:st=$(awk "BEGIN{print $cut-0.1}"):d=0.1"
	fi
	# A negative start skips that much of the take's head instead of delaying it.
	skip=$(awk "BEGIN{print ($start < 0) ? 0 - ($start) : 0}")
	delay=$(awk "BEGIN{print ($start > 0) ? $start * 1000 : 0}")
	inputs+=(-i "$sound/$file")
	chains+="[$i:a]aformat=channel_layouts=mono,aformat=sample_fmts=flt,atrim=start=$skip,asetpts=PTS-STARTPTS$trim,volume=${gain}dB,adelay=$delay[l$i];"
	labels+="[l$i]"
	i=$((i + 1))
done < <(tail -n +2 "$sound/layers")

fade_at=$(awk "BEGIN{print $length-$fade}")
ffmpeg -loglevel error -y "${inputs[@]}" -filter_complex \
	"${chains}${labels}amix=inputs=$i:normalize=0:duration=longest,atrim=0:$length,afade=t=out:st=$fade_at:d=$fade${filter:+,$filter},aresample=32000:resampler=soxr" \
	-c:a pcm_f32le "$raw"
peak=$(ffmpeg -i "$raw" -af volumedetect -f null - 2>&1 | sed -n 's/.*max_volume: \(-\{0,1\}[0-9.]*\) dB/\1/p')
ffmpeg -loglevel error -y -i "$raw" -af "volume=$(awk "BEGIN{print $target-($peak)}")dB" -ar 32000 \
	-c:a pcm_s16le "../effects/$sound.wav"
echo "../effects/$sound.wav (peak was $peak dB, now $target dB)"
