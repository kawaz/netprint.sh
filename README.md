# netprint.s

CLI からセブンイレブンの [netprint](https://www.printing.ne.jp/) に印刷ジョブ登録をするスクリプト。

# Usage
```
Usage: ./netprint.sh [OPTION]... [FILE]...
  --paperSize    0       0:A4  1:A3  2:B4  3:B5  4:photo  5:postcard
  --colorMode    2       0:プリント時に選択  1:カラー  2:白黒
  --margin       0       0:少し小さくしない  1:少し小さくする(はみ出し防止)
  --mailAddress  ""      登録成功URLの通知送信先メールアドレス (optional)
  --secretNumber ""      暗証番号4桁 (optional)
  --save                 印刷パラメータを保存する
  -d, --dry-run          印刷パラメータの確認だけする
  -q, --quit             余分な出力をしない
  -h, --help             Show help
```


