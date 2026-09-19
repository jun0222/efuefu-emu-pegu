# efuefu-emu-pegu

ffmpeg を人間が使いやすい引数の順番・ローマ字コマンドで扱う POSIX シェルスクリプト。

## 必要環境

- POSIX 準拠シェル (`sh`)
- `ffmpeg` / `ffprobe`

## 使い方

```sh
./main.sh <サブコマンド> [オプション] <入力ファイル...> [出力ファイル]
```

出力ファイルを省略すると、入力ファイル名にサフィックスを付けた名前が自動生成される。

## サブコマンド

| コマンド | 説明 | 例 |
|---|---|---|
| `chijimeru` | 動画/画像の幅を1080pxまでに縮小(縦横比維持) | `main.sh chijimeru movie.mov` |
| `bayasoku` | 動画をn倍速にする | `main.sh bayasoku 2 movie.mov` |
| `kiridasu` | 必要な範囲だけ切り出す | `main.sh kiridasu 11:01~12:32 movie.mov` |
| `gifka` | 動画を画質を保ったままGIFに変換 | `main.sh gifka movie.mov` |
| `sakujo` | メタデータ(`-m`)や音声(`-o`)を削除 | `main.sh sakujo -m -o movie.mov` |
| `kurikaesu` | 同じ内容をn回繰り返す | `main.sh kurikaesu 3 movie.mov` |
| `tsunageru` | 複数ファイルを渡した順に連結 | `main.sh tsunageru a.mov b.mov out.mov` |
| `onseika` | 動画から音声を抽出 | `main.sh onseika movie.mov` |
| `kizamu` | n秒ごとに分割 | `main.sh kizamu 30 movie.mov` |
| `asshuku` | 画像を画質を保ったまま圧縮 | `main.sh asshuku photo.jpg` |
