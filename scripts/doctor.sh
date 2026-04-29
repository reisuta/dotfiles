#!/bin/bash
# 環境の健全性チェック。
# `just doctor` から呼ばれる。何か欠けていれば赤、揃っていれば緑で表示。
#
# 副作用なし: 何かを変更したり再インストールしたりはしない。

set -uo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

ok()    { printf "  ${GREEN}✓${NC} %s\n" "$*"; }
fail()  { printf "  ${RED}✗${NC} %s\n" "$*"; FAILED=1; }
warn()  { printf "  ${YELLOW}!${NC} %s\n" "$*"; }
section() { printf "\n${YELLOW}==>${NC} %s\n" "$*"; }

FAILED=0

# OS / WSL 判定 (chezmoi と同じロジック)
case "$(uname -s)" in
    Darwin*) OS="darwin" ;;
    Linux*)  OS="linux" ;;
    *) OS="unknown" ;;
esac

IS_WSL=0
if [ "$OS" = "linux" ] && grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null; then
    IS_WSL=1
fi

DISTRO=""
if [ "$OS" = "linux" ]; then
    if [ -f /etc/arch-release ]; then
        DISTRO="arch"
    elif [ -f /etc/debian_version ]; then
        DISTRO="ubuntu"
    fi
fi

# ----------------------------------------------------------------
section "環境情報"
echo "  OS:     $OS"
[ "$OS" = "linux" ] && echo "  Distro: $DISTRO"
[ "$IS_WSL" = "1" ] && echo "  WSL:    yes"

# ----------------------------------------------------------------
section "シェル"

ZSH_PATH="$(command -v zsh || true)"
if [ -n "$ZSH_PATH" ]; then
    ok "zsh installed: $ZSH_PATH"
else
    fail "zsh not installed"
fi

if [ -n "$ZSH_PATH" ]; then
    if [ "$OS" = "darwin" ]; then
        CURRENT_SHELL="$(dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{print $2}')"
    else
        CURRENT_SHELL="$(getent passwd "$USER" | cut -d: -f7)"
    fi
    if [ "$CURRENT_SHELL" = "$ZSH_PATH" ]; then
        ok "default shell is zsh"
    else
        fail "default shell is $CURRENT_SHELL (expected $ZSH_PATH)"
    fi
fi

[ -d "$HOME/.oh-my-zsh" ] && ok "oh-my-zsh installed" || fail "oh-my-zsh missing"

P10K_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
if [ -d "$P10K_DIR" ] || command -v powerlevel10k >/dev/null 2>&1; then
    ok "powerlevel10k installed"
else
    fail "powerlevel10k missing ($P10K_DIR)"
fi

# ----------------------------------------------------------------
section "コアツール"

for tool in git nvim tmux fzf rg zoxide bat; do
    if command -v "$tool" >/dev/null 2>&1; then
        ok "$tool"
    else
        fail "$tool"
    fi
done

# eza / fd / atuin / mise / gh は環境次第なので warn 扱い
for tool in eza fd atuin mise gh; do
    if command -v "$tool" >/dev/null 2>&1; then
        ok "$tool"
    else
        warn "$tool not installed (optional)"
    fi
done

# ----------------------------------------------------------------
section "ターミナル (OS別)"

if [ "$OS" = "darwin" ]; then
    if [ -d "/Applications/WezTerm.app" ] || command -v wezterm >/dev/null 2>&1; then
        ok "WezTerm installed"
    else
        fail "WezTerm not installed (macOS のメインターミナル)"
    fi
elif [ "$OS" = "linux" ] && [ "$IS_WSL" = "0" ]; then
    if command -v kitty >/dev/null 2>&1; then
        ok "kitty installed"
    else
        fail "kitty not installed (Linux のメインターミナル)"
    fi
elif [ "$IS_WSL" = "1" ]; then
    ok "WSL: ターミナルは Windows 側で管理 (skip)"
fi

# ----------------------------------------------------------------
section "Neovim プラグイン"

if command -v nvim >/dev/null 2>&1; then
    if [ -d "$HOME/.local/share/nvim/lazy" ]; then
        plugin_count=$(find "$HOME/.local/share/nvim/lazy" -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')
        ok "lazy.nvim plugins: $plugin_count installed"
    else
        warn "lazy.nvim 未初期化 (nvim を起動すると自動インストール)"
    fi
fi

# ----------------------------------------------------------------
section "chezmoi"

if command -v chezmoi >/dev/null 2>&1; then
    ok "chezmoi installed: $(chezmoi --version | head -1)"
    pending=$(chezmoi status 2>/dev/null | wc -l | tr -d ' ')
    if [ "$pending" = "0" ]; then
        ok "chezmoi state clean (no pending changes)"
    else
        warn "chezmoi has $pending pending change(s) — run 'chezmoi diff' to see"
    fi
else
    fail "chezmoi not installed"
fi

# ----------------------------------------------------------------
echo ""
if [ "$FAILED" = "1" ]; then
    printf "${RED}=== FAIL ===${NC} 上の ✗ を確認して修正してください\n"
    exit 1
else
    printf "${GREEN}=== OK ===${NC} すべて正常です\n"
fi
