#!/bin/bash
# このリポジトリ内で唯一の素のシェルスクリプト。
# clone 直後の何もない環境で実行され、just / chezmoi をインストールしたうえで
# chezmoi に処理を引き継ぐ。
#
# 使い方:
#   git clone <repo> ~/dotfiles
#   cd ~/dotfiles && ./bootstrap.sh
#
# 対応 OS:
#   - macOS (Apple Silicon / Intel)
#   - Arch Linux (native, WSL Arch)
#   - Ubuntu / Debian (native, WSL Ubuntu)

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================================
# OS 判定
# ============================================================

OS=""
DISTRO=""
IS_WSL=0

case "$(uname -s)" in
    Darwin*)
        OS="darwin"
        ;;
    Linux*)
        OS="linux"
        if grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null; then
            IS_WSL=1
        fi
        if [ -f /etc/arch-release ]; then
            DISTRO="arch"
        elif [ -f /etc/debian_version ]; then
            DISTRO="ubuntu"
        else
            DISTRO="unknown"
        fi
        ;;
    *)
        echo "未対応 OS: $(uname -s)" >&2
        exit 1
        ;;
esac

echo "==> OS: $OS"
[ "$OS" = "linux" ] && echo "==> Distro: $DISTRO"
[ "$IS_WSL" = "1" ] && echo "==> WSL detected"

# ============================================================
# sudo セッション温存 (Linux系のみ)
# ============================================================

SUDO_KEEPALIVE_PID=""

prime_sudo() {
    if [ "$OS" = "linux" ]; then
        echo "==> sudo 認証 (パッケージインストールに必要)"
        sudo -v

        # 5分のタイムアウト中バックグラウンドで再認証して切れないようにする
        ( while true; do sudo -n true; sleep 60; kill -0 "$$" 2>/dev/null || exit; done ) &
        SUDO_KEEPALIVE_PID=$!
        trap 'kill $SUDO_KEEPALIVE_PID 2>/dev/null || true' EXIT
    fi
}

# ============================================================
# just / chezmoi インストール
# ============================================================

install_just_chezmoi() {
    case "$OS" in
        darwin)
            if ! command -v brew >/dev/null 2>&1; then
                echo "==> Installing Homebrew"
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                if [ -f /opt/homebrew/bin/brew ]; then
                    eval "$(/opt/homebrew/bin/brew shellenv)"
                fi
            fi
            command -v just      >/dev/null 2>&1 || brew install just
            command -v chezmoi   >/dev/null 2>&1 || brew install chezmoi
            ;;
        linux)
            case "$DISTRO" in
                arch)
                    sudo pacman -Syu --needed --noconfirm just chezmoi git
                    ;;
                ubuntu)
                    sudo apt update
                    sudo apt install -y git curl ca-certificates
                    # apt 標準にあれば apt 経由、なければバイナリ取得
                    if ! command -v just >/dev/null 2>&1; then
                        curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh \
                            | bash -s -- --to "$HOME/.local/bin"
                        export PATH="$HOME/.local/bin:$PATH"
                    fi
                    if ! command -v chezmoi >/dev/null 2>&1; then
                        sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
                        export PATH="$HOME/.local/bin:$PATH"
                    fi
                    ;;
                *)
                    echo "未対応のディストリビューション: $DISTRO" >&2
                    exit 1
                    ;;
            esac
            ;;
    esac
}

# ============================================================
# chezmoi 初期化 + 適用
# ============================================================

run_chezmoi() {
    echo "==> chezmoi init --source=$DOTFILES_DIR --apply"
    chezmoi init --source="$DOTFILES_DIR" --apply
}

# ============================================================
# main
# ============================================================

prime_sudo
install_just_chezmoi
run_chezmoi

echo ""
echo "============================================================"
echo "セットアップ完了。"
echo ""
echo "  just            - 利用可能なタスク一覧"
echo "  just doctor     - 環境のヘルスチェック"
echo "  chezmoi diff    - 設定変更のプレビュー"
echo "  chezmoi apply   - 設定変更の適用"
echo "  chezmoi update  - リポジトリ pull + 適用"
echo ""
echo "次回ログインから zsh がデフォルトシェルになります。"
echo "============================================================"
