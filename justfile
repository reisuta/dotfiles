# dotfiles タスクランナー (chezmoi の単純ラッパーは含めない方針)
#
# 使い方: `just <task>`、または引数なしで `just` で一覧表示
#
# 棲み分け:
#   - 設定ファイルの apply / diff / update / edit は `chezmoi` を直接叩く
#   - ここには chezmoi 単体ではできないタスクのみ集約する

set shell := ["bash", "-cu"]
set dotenv-load := false

# デフォルト: 利用可能タスク一覧
default:
    @just --list --unsorted

# 初回セットアップ (chezmoi が無ければ取得し、このリポジトリを source として init --apply)
install:
    @command -v chezmoi >/dev/null 2>&1 || sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
    PATH="$HOME/.local/bin:$PATH" chezmoi init --source={{ justfile_directory() }} --apply

# 環境ヘルスチェック (副作用なし)
doctor:
    @bash {{ justfile_directory() }}/scripts/doctor.sh

# シェルスクリプトの静的解析
lint:
    @command -v shellcheck >/dev/null || { echo "shellcheck がインストールされていません"; exit 1; }
    shellcheck scripts/doctor.sh
    @echo "==> .tmpl は chezmoi が処理する形式なので shellcheck 対象外"

# Neovim プラグインを最新化 (lazy.nvim sync)
plugins-update:
    nvim --headless "+Lazy! sync" +qa
    @echo "==> Neovim plugins synced"

# 現在のローカル brew 環境から Brewfile を再生成 (macOS 専用)
brewfile-dump:
    @[ "$(uname -s)" = "Darwin" ] || { echo "macOS 専用です"; exit 1; }
    brew bundle dump --file=Brewfile --force
    @echo "==> Brewfile updated. git diff で変更を確認してください。"

# 現在の chezmoi 管理状態をアーカイブ (バックアップ)
backup:
    chezmoi archive --output="backup-$(date +%Y%m%d-%H%M).tar.gz"
    @echo "==> backup-$(date +%Y%m%d-%H%M).tar.gz を作成しました"

# ------------------------------------------------------------
# WSL イメージ (システム層)
# ------------------------------------------------------------

# Dockerfile からイメージをビルド (identity は手元の id から注入)
image-build tag="wsl-ubuntu":
    docker build \
        --build-arg USERNAME="$(id -un)" \
        --build-arg UID="$(id -u)" \
        --build-arg GID="$(id -g)" \
        -t {{ tag }} .
    @echo "==> {{ tag }} をビルドしました。`just image-shell` で中を確認できます。"

# ビルドしたイメージの中に入って確認 (import 前の試着)
image-shell tag="wsl-ubuntu":
    docker run --rm -it {{ tag }} /usr/bin/zsh -l

# イメージを新しい WSL ディストロとして import (既存 Ubuntu には触らない)
# save ではなく export。save は OCI アーカイブで WSL が読めない。
image-to-wsl name="ubuntu-iac" tag="wsl-ubuntu":
    #!/usr/bin/env bash
    set -euo pipefail
    win_home=$(wslpath "$(powershell.exe -NoProfile -Command 'Write-Output $env:USERPROFILE' | tr -d '\r')")
    dest="${win_home}/WSL/{{ name }}"
    tar="${win_home}/WSL/{{ name }}.tar"
    mkdir -p "${win_home}/WSL"

    cid=$(docker create {{ tag }})
    trap 'docker rm -f "$cid" >/dev/null 2>&1 || true' EXIT
    docker export "$cid" -o "$tar"

    wsl.exe --import "{{ name }}" "$(wslpath -w "$dest")" "$(wslpath -w "$tar")"
    rm -f "$tar"

    echo "==> 完了: wsl -d {{ name }} / 削除: wsl --unregister {{ name }}"

# ビルド → import を一括実行
wsl-image name="ubuntu-iac": image-build (image-to-wsl name)

# chezmoi 管理対象 + 未管理ファイルの一覧
status:
    @echo "==> chezmoi 管理対象 (差分があるもの):"
    @chezmoi status || true
    @echo ""
    @echo "==> chezmoi で管理されている全ファイル:"
    @chezmoi managed | head -30
