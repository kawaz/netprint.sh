#!/usr/bin/env bash
set -e
set -o pipefail

usage() {
  echo "Usage: $0 [OPTION]... [FILE]..."
  echo '  --paperSize    0       0:A4  1:A3  2:B4  3:B5  4:photo  5:postcard'
  echo '  --colorMode    2       0:プリント時に選択  1:カラー  2:白黒'
  echo '  --margin       0       0:少し小さくしない  1:少し小さくする(はみ出し防止)'
  echo '  --mailAddress  ""      登録成功URLの通知送信先メールアドレス (optional)'
  echo '  --secretNumber ""      暗証番号4桁 (optional)'
  echo '  --save                 印刷パラメータを保存する'
  echo '  -d, --dry-run          印刷パラメータの確認だけする'
  echo '  -q, --quit             余分な出力をしない'
  echo '  -h, --help             Show help'
  exit 1
}
#[[ $# == 0 && ! -p /dev/stdin ]] && usage
[[ $# == 0 ]] && usage

echov() {
  echo "$@" >&2
}
for _ in "$@"; do [[ $_ =~ ^(--quit|-q)$ ]] && echov() { :; }; done

# show requirements
(( BASH_VERSINFO < 4 )) && { echov "$0 require bash version up to 4.0"; exit 1; }
type jq >/dev/null 2>&1 || { echov "$0 require jq"; exit 1; }
type curl >/dev/null 2>&1 || { echov "$0 require curl"; exit 1; }

declare -A opts=(
  [paperSize]=0
  [colorMode]=2
  [margin]=0
  [mailAddress]=
  [secretNumber]=
)
config_file="${XDG_CACHE_HOME:-~/.cache}/netprint.sh/opts.sh"
if [[ -f $config_file ]]; then
  # デフォルトオプションをロード
  echov "Load config: $config_file"
  . "$config_file"
fi
file= save= dryRun= pre= cur=
for cur in "" "$@"; do
  if [[ -n $pre ]]; then
    if [[ "$pre $cur" =~ ^--(paperSize [0-5]|colorMode [01]|margin [01]|mailAddress (.+@.+)?|secretNumber ([0-9]{4})?)$ ]]; then
      opts[${pre:2}]=$cur
      pre=
      continue
    else
      usage
    fi
  fi
  [[ $cur =~ ^(--help|-h)$ ]] && usage
  [[ $cur =~ ^(--dry-run|-d) ]] && { dryRun=1; continue; }
  [[ $cur =~ ^--(paperSize|colorMode|margin|mailAddress|secretNumber)$ ]] && { pre=$cur; continue; }
  [[ $cur == --save ]] && { save=1; continue; }
  [[ -f $cur ]] && { file=$cur; continue; }
  pre=$cur
done
if [[ $save == 1 ]]; then
  # デフォルトオプションを保存
  echov "Save config: $config_file"
  [[ -d ${config_file%/*} ]] || mkdir -p "${config_file%/*}"
  for k in "${!opts[@]}"; do printf "opts[%q]=%q\n" "$k" "${opts[$k]}"; done > "$config_file"
fi
#[[ -p /dev/stdin ]] && file=-

# ネットプリント実行
opts[fileBody]="@$file"
curl_opts=(); for k in "${!opts[@]}"; do curl_opts+=( -F "$k=${opts[$k]}" ); echov "$k=${opts[$k]}"; done
[[ $dryRun == 1 ]] && { exit; }
[[ -n $file ]] || usage
useridentifier=$(curl -sL https://lite.printing.ne.jp/web/ | grep -Eo '<input[^>]* id="useridentifier" [^>]*>' | perl -pe's/.* value="(.*?)".*/$1/')
res_registerFile=$(curl -s 'https://lite.printing.ne.jp/api/register-file' -H "x-nps-lite-id: $useridentifier" "${curl_opts[@]}")
fileId=$(jq -r .id <<<"$res_registerFile")
# 登録完了待ち
while :; do
  res_registrationStatus=$(curl -sL -H "x-nps-lite-id: $useridentifier" "https://lite.printing.ne.jp/api/registration-status/$fileId?_=$RANDOM")
  resultCode=$(jq -r .resultCode <<<"$res_registrationStatus")
  [[ $resultCode != 1 ]] && break
  echov "$res_registrationStatus"
  sleep 1
done
# 登録情報表示
jq . <<<"$res_registrationStatus"

