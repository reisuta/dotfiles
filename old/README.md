# old/

過去に使っていたが現在は使用していない設定ファイル群を保管しているディレクトリです。
削除はせず、いつでも参照・復元できる状態にしてあります。

## 内容

| ファイル | 概要 | 退役理由 |
|---|---|---|
| `alacritty.toml` | Windows + WSL2 用の Alacritty 設定 | Windows でも WezTerm を使うようになったため不要 |
| `init.vim` | 旧 Vim/Neovim の Vimscript 設定 | Lua (`init.lua`) に完全移行済み |
| `hyper.js` | Hyper Terminal の設定 | 使用ターミナルが kitty / WezTerm に移行 |
| `p10k2.zsh` | Powerlevel10k の設定バリエーション | メインの `p10k.zsh` に統一 |
| `sl-p10k.zsh` | Powerlevel10k の設定バリエーション | 同上 |
| `config.json` | 用途不明の旧設定ファイル | 現環境では参照していない |
| `my_theme.py` | カスタム Python スクリプト | 現環境では参照していない |
| `initial.sh` | 旧初期化スクリプト | `bootstrap.sh` に統合 |
| `my_command/` | 旧 tmux ペイン構築スクリプト群 | 現在は使用していない |
| `setup.sh` | 旧シンボリックリンク貼付スクリプト | chezmoi に置き換え |

## 復元したくなったら

```bash
git mv old/<ファイル名> ./
```

履歴はそのまま残っているので `git log --follow old/<ファイル>` で過去のコミットを追えます。
