#!/bin/sh
#
# ffmpeg を人間が使いやすい引数の順番・ローマ字コマンドで扱うためのラッパー
#
set -eu

WIDTH_LIMIT=1080

err() {
	printf 'エラー: %s\n' "$1" >&2
	exit 1
}

require_ffmpeg() {
	command -v ffmpeg >/dev/null 2>&1 || err "ffmpeg が見つかりません。インストールしてください。"
	command -v ffprobe >/dev/null 2>&1 || err "ffprobe が見つかりません。インストールしてください。"
}

check_file() {
	[ -f "$1" ] || err "ファイルが見つかりません: $1"
}

# 相対パスを絶対パスにする (concat リストなど別ディレクトリから参照する場合に必要)
abspath() {
	case "$1" in
	/*) printf '%s\n' "$1" ;;
	*) printf '%s/%s\n' "$(pwd)" "$1" ;;
	esac
}

# gen_output <input> <suffix> <newext>
# suffix, newext は空文字を渡すと「付けない/元のまま」を意味する
gen_output() {
	dir=$(dirname "$1")
	base=$(basename "$1")
	name=${base%.*}
	ext=${base##*.}
	[ -n "$3" ] && ext=$3
	if [ -n "$2" ]; then
		printf '%s/%s_%s.%s\n' "$dir" "$name" "$2" "$ext"
	else
		printf '%s/%s.%s\n' "$dir" "$name" "$ext"
	fi
}

usage() {
	cat <<'EOM'
使い方: main.sh <サブコマンド> [オプション] <入力ファイル...> [出力ファイル]

サブコマンド:
  chijimeru <入力> [出力]                 動画/画像の幅を1080pxまでに縮小する(縦横比維持)
  bayasoku  <倍率> <入力> [出力]          動画をn倍速にする
  kiridasu  <開始~終了> <入力> [出力]     動画/音声を必要な範囲だけ切り出す (例: 11:01~12:32)
  gifka     <入力> [出力]                 動画を画質を保ったままgifに変換する
  sakujo    [-m] [-o] <入力> [出力]       メタデータ(-m)や音声(-o)を削除する
  kurikaesu <回数> <入力> [出力]          動画/音声を同じ内容でn回繰り返す
  tsunageru <入力...> <出力>              複数の動画/音声を渡した順番に繋げる
  onseika   <入力> [出力]                 動画から音声データを取り出す
  kizamu    <秒数> <入力> [出力プレフィックス]  動画/音声をn秒ごとに分割する
  asshuku   <入力> [出力]                 画像を画質を保ったまま圧縮する
EOM
}

# build_atempo <倍率>
# ffmpeg の atempo フィルタは 0.5~2.0 の範囲しか受け付けないため、
# 範囲外の倍率は複数の atempo をチェインして表現する
build_atempo() {
	awk -v f="$1" 'BEGIN {
		if (f <= 0) { exit 1 }
		chain = ""
		while (f > 2.0) { chain = chain "atempo=2.0,"; f = f / 2.0 }
		while (f < 0.5) { chain = chain "atempo=0.5,"; f = f / 0.5 }
		printf "%satempo=%.6f", chain, f
	}'
}

has_audio_stream() {
	ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$1" 2>/dev/null | grep -q .
}

cmd_chijimeru() {
	[ $# -ge 1 ] || err "使い方: main.sh chijimeru <入力> [出力]"
	input=$1
	check_file "$input"
	output=${2:-$(gen_output "$input" "1080" "")}

	width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$input")
	if [ "$width" -le "$WIDTH_LIMIT" ]; then
		ffmpeg -i "$input" -c copy -y "$output"
		return
	fi

	case "$input" in
	*.mov | *.MOV | *.mp4 | *.MP4)
		ffmpeg -i "$input" -vf "scale=${WIDTH_LIMIT}:-2" -c:a copy -y "$output"
		;;
	*.jpg | *.JPG | *.jpeg | *.JPEG | *.png | *.PNG)
		ffmpeg -i "$input" -vf "scale=${WIDTH_LIMIT}:-1" -y "$output"
		;;
	*)
		err "対応していない拡張子です: $input"
		;;
	esac
}

cmd_bayasoku() {
	[ $# -ge 2 ] || err "使い方: main.sh bayasoku <倍率> <入力> [出力]"
	bairitsu=$1
	input=$2
	check_file "$input"
	output=${3:-$(gen_output "$input" "x${bairitsu}" "")}

	if has_audio_stream "$input"; then
		atempo=$(build_atempo "$bairitsu") || err "倍率が不正です: $bairitsu"
		ffmpeg -i "$input" \
			-filter_complex "[0:v]setpts=PTS/${bairitsu}[v];[0:a]${atempo}[a]" \
			-map "[v]" -map "[a]" -y "$output"
	else
		ffmpeg -i "$input" -vf "setpts=PTS/${bairitsu}" -an -y "$output"
	fi
}

cmd_kiridasu() {
	[ $# -ge 2 ] || err "使い方: main.sh kiridasu <開始~終了> <入力> [出力]"
	hani=$1
	input=$2
	check_file "$input"
	output=${3:-$(gen_output "$input" "kiridashi" "")}

	case "$hani" in
	*~*)
		start=${hani%%~*}
		owari=${hani#*~}
		;;
	*-*)
		start=${hani%%-*}
		owari=${hani#*-}
		;;
	*)
		err "範囲の形式が不正です (例: 11:01~12:32): $hani"
		;;
	esac

	ffmpeg -ss "$start" -to "$owari" -i "$input" -c copy -y "$output"
}

cmd_gifka() {
	[ $# -ge 1 ] || err "使い方: main.sh gifka <入力> [出力]"
	input=$1
	check_file "$input"
	output=${2:-$(gen_output "$input" "" "gif")}

	ffmpeg -i "$input" -filter_complex \
		"fps=15,scale=iw:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" \
		-y "$output"
}

cmd_sakujo() {
	metadata_flag=0
	onsei_flag=0
	OPTIND=1
	while getopts "mo" opt "$@"; do
		case "$opt" in
		m) metadata_flag=1 ;;
		o) onsei_flag=1 ;;
		*) err "使い方: main.sh sakujo [-m] [-o] <入力> [出力]" ;;
		esac
	done
	shift $((OPTIND - 1))

	[ "$metadata_flag" -eq 1 ] || [ "$onsei_flag" -eq 1 ] ||
		err "-m (メタデータ削除) か -o (音声削除) のどちらかを指定してください"
	[ $# -ge 1 ] || err "使い方: main.sh sakujo [-m] [-o] <入力> [出力]"

	input=$1
	check_file "$input"
	output=${2:-$(gen_output "$input" "sakujo" "")}

	set -- -i "$input"
	[ "$metadata_flag" -eq 1 ] && set -- "$@" -map_metadata -1
	if [ "$onsei_flag" -eq 1 ]; then
		set -- "$@" -an -c:v copy
	else
		set -- "$@" -c copy
	fi
	ffmpeg "$@" -y "$output"
}

cmd_kurikaesu() {
	[ $# -ge 2 ] || err "使い方: main.sh kurikaesu <回数> <入力> [出力]"
	kaisuu=$1
	input=$2
	check_file "$input"
	output=${3:-$(gen_output "$input" "x${kaisuu}" "")}

	[ "$kaisuu" -ge 1 ] 2>/dev/null || err "回数は1以上の整数で指定してください: $kaisuu"
	loop=$((kaisuu - 1))
	ffmpeg -stream_loop "$loop" -i "$input" -c copy -y "$output"
}

cmd_tsunageru() {
	[ $# -ge 3 ] || err "使い方: main.sh tsunageru <入力...> <出力> (入力は2つ以上)"

	list_file=$(mktemp)
	trap 'rm -f "$list_file"' EXIT

	total=$#
	i=0
	for arg in "$@"; do
		i=$((i + 1))
		if [ "$i" -eq "$total" ]; then
			output=$arg
		else
			check_file "$arg"
			printf "file '%s'\n" "$(abspath "$arg")" >>"$list_file"
		fi
	done

	ffmpeg -f concat -safe 0 -i "$list_file" -c copy -y "$output"
}

cmd_onseika() {
	[ $# -ge 1 ] || err "使い方: main.sh onseika <入力> [出力]"
	input=$1
	check_file "$input"
	output=${2:-$(gen_output "$input" "" "m4a")}

	ffmpeg -i "$input" -vn -y "$output"
}

cmd_kizamu() {
	[ $# -ge 2 ] || err "使い方: main.sh kizamu <秒数> <入力> [出力プレフィックス]"
	byou=$1
	input=$2
	check_file "$input"

	dir=$(dirname "$input")
	base=$(basename "$input")
	ext=${base##*.}
	name=${base%.*}
	prefix=${3:-"${dir}/${name}_kizami"}

	ffmpeg -i "$input" -f segment -segment_time "$byou" -reset_timestamps 1 \
		-c copy -y "${prefix}_%03d.${ext}"
}

cmd_asshuku() {
	[ $# -ge 1 ] || err "使い方: main.sh asshuku <入力> [出力]"
	input=$1
	check_file "$input"
	output=${2:-$(gen_output "$input" "asshuku" "")}

	case "$input" in
	*.jpg | *.JPG | *.jpeg | *.JPEG)
		ffmpeg -i "$input" -qscale:v 4 -y "$output"
		;;
	*.png | *.PNG)
		ffmpeg -i "$input" -compression_level 9 -y "$output"
		;;
	*)
		err "対応していない拡張子です: $input"
		;;
	esac
}

main() {
	if [ $# -eq 0 ]; then
		usage
		exit 1
	fi

	case "$1" in
	-h | --help)
		usage
		exit 0
		;;
	esac

	require_ffmpeg

	subcommand=$1
	shift
	case "$subcommand" in
	chijimeru) cmd_chijimeru "$@" ;;
	bayasoku) cmd_bayasoku "$@" ;;
	kiridasu) cmd_kiridasu "$@" ;;
	gifka) cmd_gifka "$@" ;;
	sakujo) cmd_sakujo "$@" ;;
	kurikaesu) cmd_kurikaesu "$@" ;;
	tsunageru) cmd_tsunageru "$@" ;;
	onseika) cmd_onseika "$@" ;;
	kizamu) cmd_kizamu "$@" ;;
	asshuku) cmd_asshuku "$@" ;;
	*)
		usage
		err "不明なサブコマンドです: $subcommand"
		;;
	esac
}

main "$@"
