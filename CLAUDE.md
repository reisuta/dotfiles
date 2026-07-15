# dotfiles

chezmoi 管理。`~/dotfiles` を source に apply。macOS / Arch / WSL Ubuntu を
`.chezmoiignore.tmpl` と `run_once_*.tmpl` の OS 分岐で出し分ける。

## パッケージの正
apt=`aptpkgs.txt` / npm=`npmpkgs.txt` / brew=`Brewfile` / pacman=`archpkgs*.txt`。
これらが唯一の正で、Dockerfile と chezmoi の両方が読む。追加はリストだけ編集する。

## 注意点
- 公開 repo。実ユーザー名・メール・社内情報を書かない（identity はビルド時に注入）。
- node は移行途中。実機は nvm(v24)、あるべき姿は mise 一本。
  `mise.docker.toml` を `mise.toml` にすると mise が実機で自動検出するため改名してある。
- `/etc/wsl.conf` はホーム外。`run_once_after_wsl-conf.sh.tmpl` が sudo で配置する。

## WSL イメージ
`just wsl-image` で Dockerfile から新 WSL ディストロを作る。既存 Ubuntu には触らない。
