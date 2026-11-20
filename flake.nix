# macOS のパッケージ定義 (nix-darwin)。旧 Brewfile の置き換え。
# run_once_before_install-packages.sh.tmpl から
#   sudo darwin-rebuild switch --flake <dotfiles>#<arch>-darwin
# として適用される。dotfiles の配置は chezmoi の担当なので home-manager は使わない。
#
# 注意:
#   - flake は git 管理下のファイルしか見ない。このファイルを編集・新規追加したら
#     少なくとも `git add` してから適用すること。
#   - ユーザー名など個人情報はここに書かない (公開 repo)。
#   - zsh は macOS 標準の /bin/zsh を使うのでここには入れない。
{
  description = "dotfiles: macOS packages via nix-darwin";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nix-darwin }:
    let
      mkDarwin = system: nix-darwin.lib.darwinSystem {
        modules = [
          ({ pkgs, ... }: {
            nixpkgs.hostPlatform = system;

            # Nix 本体は Determinate Nix が管理するので nix-darwin には触らせない
            nix.enable = false;

            environment.systemPackages = with pkgs; [
              # シェル・ターミナル基盤
              git
              tmux
              neovim

              # CLI ユーティリティ (zshrc / aliases で参照)
              fzf
              ripgrep
              fd
              bat
              eza
              zoxide
              atuin

              # プロンプト
              starship

              # バージョン管理 (zshrc で `mise activate zsh` 使用)
              mise

              # タスクランナー (justfile を実行)
              just

              # GitHub CLI
              gh

              # dotfiles 管理
              chezmoi

              # ターミナル (macOS のメインターミナル)。.app は /Applications/Nix Apps に入る
              wezterm
            ];

            # フォント (kitty.conf / WezTerm で使用)
            fonts.packages = [ pkgs.nerd-fonts.monaspace ];

            # 初回適用時の値で固定する (上げるときは nix-darwin の changelog を読む)
            system.stateVersion = 6;
          })
        ];
      };
    in
    {
      darwinConfigurations = {
        "aarch64-darwin" = mkDarwin "aarch64-darwin";
        "x86_64-darwin" = mkDarwin "x86_64-darwin";
      };
    };
}
