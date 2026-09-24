# efuefu-emu-pegu

ffmpeg を人間が使いやすい引数の順番・ローマ字コマンドで扱う POSIX シェルスクリプト。

## 必要環境

- POSIX 準拠シェル (`sh`)
- `ffmpeg` / `ffprobe`

## インストール

リポジトリをダウンロードしたら `main.sh` に実行権限を付け、PATHの通ったディレクトリへシンボリックリンクを張ると、リポジトリの場所を意識せずどこからでも短いコマンド名で呼び出せる。

```sh
chmod +x main.sh
ln -s "$(pwd)/main.sh" /usr/local/bin/eep
```

`/usr/local/bin` に書き込み権限がない場合は `~/.local/bin` など、自分のPATHに含まれる任意のディレクトリを代わりに指定する(未登録なら `export PATH="$HOME/.local/bin:$PATH"` をシェルの設定ファイルに追加する)。リンク先の実体はリポジトリ内の `main.sh` のままなので、`git pull` で更新すればリンク経由の呼び出しにも即座に反映される。不要になったら `rm /usr/local/bin/eep` でリンクだけを削除すればよく、リポジトリ本体には影響しない。

## 使い方

シンボリックリンクを張った場合:

```sh
eep <サブコマンド> [オプション] <入力ファイル...> [出力ファイル]
```

リポジトリ内で直接実行する場合:

```sh
./main.sh <サブコマンド> [オプション] <入力ファイル...> [出力ファイル]
```

出力ファイルを省略すると、入力ファイル名にサフィックスを付けた名前が自動生成される。その際、動画の出力は`.mp4`、音声の出力は`.mp3`に統一される(入力が`.mov`や`.m4a`等でも変換される)。画像はもとの拡張子(`.jpg`/`.png`)のまま出力する。

## サブコマンド

| コマンド | 説明 | 例 |
|---|---|---|
| `chijimeru` | 動画/画像の幅を1080pxまでに縮小(縦横比維持) | `main.sh chijimeru movie.mov` |
| `baisoku` | 動画をn倍速にする | `main.sh baisoku 2 movie.mov` |
| `kiridasu` | 必要な範囲だけ切り出す | `main.sh kiridasu 11:01~12:32 movie.mov` |
| `gifka` | 動画を画質を保ったままGIFに変換 | `main.sh gifka movie.mov` |
| `sakujo` | メタデータ(`-m`)や音声(`-o`)を削除 | `main.sh sakujo -m -o movie.mov` |
| `kurikaesu` | 同じ内容をn回繰り返す | `main.sh kurikaesu 3 movie.mov` |
| `tsunageru` | 複数ファイルを渡した順に連結 | `main.sh tsunageru a.mov b.mov out.mov` |
| `onseika` | 動画から音声を抽出 | `main.sh onseika movie.mov` |
| `kizamu` | n秒ごとに分割 | `main.sh kizamu 30 movie.mov` |
| `asshuku` | 動画/画像を画質を保ったまま圧縮 | `main.sh asshuku movie.mp4` |

## テスト

`test.sh` が ffmpeg 標準のテスト用ソース(`testsrc`/`sine`)でサンプル動画・画像をその場生成し、各サブコマンドを一通り実行して結果を検証する。実ファイル不要でそのまま実行できる。

```sh
./test.sh
```
