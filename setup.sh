#!/bin/bash
# dotfiles セットアップスクリプト
# 実行すると各設定ファイルをシンボリックリンクで配置する

DOTFILES="$(cd "$(dirname "$0")" && pwd)"

link() {
  local src="$DOTFILES/$1"
  local dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    echo "backup: $dst -> $dst.bak"
    mv "$dst" "$dst.bak"
  fi
  ln -sf "$src" "$dst"
  echo "linked: $dst -> $src"
}

link zshrc       ~/.zshrc
link tmux.conf   ~/.tmux.conf
link init.lua    ~/.config/nvim/init.lua
link lua         ~/.config/nvim/lua
link p10k.zsh    ~/.p10k.zsh

echo ""
echo "完了。既存ファイルは .bak で保存済み。"
