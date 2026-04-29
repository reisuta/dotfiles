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

# 新規環境の初期セットアップ (clone 直後の1コマンド)
install:
    ./bootstrap.sh

# 環境ヘルスチェック (副作用なし)
doctor:
    @bash {{ justfile_directory() }}/scripts/doctor.sh

# Arch Linux コンテナで bootstrap が壊れていないか検証
test-arch:
    docker run --rm -it \
        -v "{{ justfile_directory() }}:/dotfiles:ro" \
        archlinux:latest bash -c \
        "pacman -Sy --noconfirm git sudo zsh && \
         cp -r /dotfiles /root/dotfiles && \
         cd /root/dotfiles && \
         ./bootstrap.sh"

# Ubuntu コンテナで bootstrap が壊れていないか検証
test-ubuntu:
    docker run --rm -it \
        -v "{{ justfile_directory() }}:/dotfiles:ro" \
        ubuntu:latest bash -c \
        "apt update && \
         apt install -y git curl sudo zsh && \
         cp -r /dotfiles /root/dotfiles && \
         cd /root/dotfiles && \
         ./bootstrap.sh"

# 全 OS でテスト (CI 用)
test: test-arch test-ubuntu

# シェルスクリプトの静的解析
lint:
    @command -v shellcheck >/dev/null || { echo "shellcheck がインストールされていません"; exit 1; }
    shellcheck bootstrap.sh scripts/doctor.sh
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

# chezmoi 管理対象 + 未管理ファイルの一覧
status:
    @echo "==> chezmoi 管理対象 (差分があるもの):"
    @chezmoi status || true
    @echo ""
    @echo "==> chezmoi で管理されている全ファイル:"
    @chezmoi managed | head -30
