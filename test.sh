#!/bin/sh
#
# main.sh の結合テスト。ffmpeg 標準のテスト用ソース(testsrc/sine)で
# サンプル動画・画像をその場生成し、各サブコマンドを検証する。
#
set -eu

MAIN=$(cd "$(dirname "$0")" && pwd)/main.sh
WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT
cd "$WORKDIR"

pass_count=0
fail_count=0

pass() {
	pass_count=$((pass_count + 1))
	printf 'PASS: %s\n' "$1"
}

fail() {
	fail_count=$((fail_count + 1))
	printf 'FAIL: %s -- %s\n' "$1" "$2"
}

assert_file_exists() {
	if [ -s "$2" ]; then
		pass "$1"
	else
		fail "$1" "ファイルが存在しません: $2"
	fi
}

assert_width() {
	w=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$2")
	if [ "$w" -eq "$3" ]; then
		pass "$1"
	else
		fail "$1" "幅が期待値と異なります (実際: $w, 期待: $3)"
	fi
}

assert_duration_near() {
	d=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$2")
	ok=$(awk -v d="$d" -v e="$3" -v t="$4" \
		'BEGIN { diff = d - e; if (diff < 0) diff = -diff; print (diff <= t) ? 1 : 0 }')
	if [ "$ok" -eq 1 ]; then
		pass "$1"
	else
		fail "$1" "再生時間が期待値と異なります (実際: ${d}s, 期待: ${3}s前後)"
	fi
}

assert_no_stream() {
	sel=v
	[ "$3" = "audio" ] && sel=a
	found=$(ffprobe -v error -select_streams "$sel" -show_entries stream=index -of csv=p=0 "$2" 2>/dev/null || true)
	if [ -z "$found" ]; then
		pass "$1"
	else
		fail "$1" "$3 ストリームが残っています"
	fi
}

# --- テスト用素材の生成 ---
ffmpeg -y -loglevel error \
	-f lavfi -i "testsrc=size=1920x1080:duration=3:rate=15" \
	-f lavfi -i "sine=frequency=440:duration=3" \
	-c:v libx264 -c:a aac -pix_fmt yuv420p sample.mp4
ffmpeg -y -loglevel error -f lavfi -i "testsrc=size=1920x1080" -frames:v 1 sample.jpg

# --- 各サブコマンドの検証 ---
"$MAIN" chijimeru sample.mp4 >/dev/null 2>&1
assert_width "chijimeru: 動画の幅が1080pxになる" sample_1080.mp4 1080

"$MAIN" chijimeru sample.jpg >/dev/null 2>&1
assert_width "chijimeru: 画像の幅が1080pxになる" sample_1080.jpg 1080

"$MAIN" bayasoku 2 sample.mp4 >/dev/null 2>&1
assert_duration_near "bayasoku: 2倍速で再生時間が半分になる" sample_x2.mp4 1.5 0.3

"$MAIN" kiridasu 0:00~0:01 sample.mp4 >/dev/null 2>&1
assert_duration_near "kiridasu: 指定範囲(1秒)だけ切り出される" sample_kiridashi.mp4 1.0 0.3

"$MAIN" gifka sample.mp4 >/dev/null 2>&1
assert_file_exists "gifka: GIFファイルが生成される" sample.gif

"$MAIN" sakujo -o sample.mp4 >/dev/null 2>&1
assert_no_stream "sakujo: -oで音声ストリームが削除される" sample_sakujo.mp4 audio

"$MAIN" kurikaesu 3 sample.mp4 >/dev/null 2>&1
assert_duration_near "kurikaesu: 3回繰り返しで再生時間が3倍になる" sample_x3.mp4 9.0 0.5

"$MAIN" tsunageru sample.mp4 sample_x2.mp4 sample_tsunageta.mp4 >/dev/null 2>&1
assert_duration_near "tsunageru: 2つの動画の合計時間になる" sample_tsunageta.mp4 4.5 0.5

"$MAIN" onseika sample.mp4 >/dev/null 2>&1
assert_file_exists "onseika: mp3ファイルが生成される" sample.mp3
assert_no_stream "onseika: 映像ストリームが含まれない" sample.mp3 video

"$MAIN" kiridasu 0:00~0:01 sample.mp3 >/dev/null 2>&1
assert_duration_near "kiridasu: mp3を切り出してもmp3のまま" sample_kiridashi.mp3 1.0 0.3

"$MAIN" kurikaesu 3 sample.mp3 >/dev/null 2>&1
assert_duration_near "kurikaesu: mp3を繰り返してもmp3のまま" sample_x3.mp3 9.0 0.5

"$MAIN" kizamu 1 sample.mp3 >/dev/null 2>&1
assert_file_exists "kizamu: mp3の分割ファイルが生成される" sample_kizami_000.mp3

"$MAIN" kizamu 1 sample.mp4 >/dev/null 2>&1
assert_file_exists "kizamu: 分割ファイルが生成される" sample_kizami_000.mp4

"$MAIN" asshuku sample.jpg >/dev/null 2>&1
assert_file_exists "asshuku: 圧縮後の画像が生成される" sample_asshuku.jpg

printf '\n%d件成功 / %d件失敗\n' "$pass_count" "$fail_count"
[ "$fail_count" -eq 0 ]
