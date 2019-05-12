# kamishibai
紙芝居動画メーカー

## 依存
**Windows 10 + WSL(Ubuntu 18.04) 環境で書いています。WSL内でしか動かないかは分かりませんが、SeikaCenterに依存するのでWindows環境であることは少なくとも必須です。**

### 必須
- Perl 5.14以降
    - plenvの使用をおすすめします
    - 開発に使っているのは version 5.28.2 です
- Rake
    - `$ sudo apt install ruby`
- FFMpeg
    - `$ sudo apt install ffmpeg`
- Imager
    - まずFreetypeやlibpngを入れておいてください。
        - `$ sudo apt install libjpeg-dev libtiff-dev libpng-dev giflib-dev libttf-dev libfreetype6-dev`
    - `$ cpanm Imager`

### 音声系
読み上げ音声挿入機能を使わない場合は不要ですが、今の所この機能をオフにする簡単な方法を提供していないので、ソースを編集してその部分を消す必要があります。

- Audio::Wav
    - `$ cpanm Audio::Wav`
- SeikaCenter
    - https://hgotoh.jp/wiki/doku.php/documents/voiceroid/seikacenter よりダウンロードしてWindows側にインストール
    - `saikasay.exe` をパスの通った場所に置いてください
- 音声ライブラリ
    - Voiceroid+EX 東北きりたんでしか確認していませんが、SeikaCenterが対応するものならきっと動くでしょう

## 使い方
1. このリポジトリを **Windows側から見える場所に**clone
    - `$ git clone https://github.com/suzusime/kamishibai.git`
    - WSL内のディレクトリではだめです

1. `make_script.pl` のCID部分を使うキャラクターに合わせて変更
    - CIDとはSeikaCenterがキャラを管理するための番号です。詳しくはSeikaCenterのドキュメントを参照してください
    
    ```perl
    #ここを編集
    my $cid = 1700;
    ```
1. `make_script.pl` の実行ファイルパス部分を、このスクリプトを置いた場所（＝リポジトリをcloneした場所）に合わせて変更
    - WSLからWindows側の絶対パスをとる方法がよくわからないので手書きするようにしています

    ```perl
    # Windowsから見た実行ディレクトリの絶対パス
    my $dirpath = "D:/projects/kamishibai";
    ```

1. SeikaCenterと音声ライブラリを起動する

1. `$ rake`

# ライセンス
[LICENSE](LICENSE)を参照してください。