# dotfiles

クロスプラットフォーム (macOS / Arch Linux / Ubuntu / WSL) で動く設定ファイル群。
[chezmoi](https://www.chezmoi.io/) を使って 1 コマンドで環境構築できる。

---

## 目次

- [クイックスタート](#クイックスタート)
- [対応 OS](#対応-os)
- [コマンドリファレンス](#コマンドリファレンス)
  - [初回セットアップ系](#初回セットアップ系)
  - [日常運用系 (chezmoi)](#日常運用系-chezmoi)
  - [メンテナンス系 (just)](#メンテナンス系-just)
  - [緊急/トラブル対応系](#緊急トラブル対応系)
- [状況別チートシート](#状況別チートシート)
- [ツール棲み分け](#ツール棲み分け)
- [ディレクトリ構成](#ディレクトリ構成)
- [chezmoi の命名規則](#chezmoi-の命名規則-この-repo-で使うもの)

---

## クイックスタート

```bash
git clone https://github.com/reisuta/dotfiles ~/dotfiles
cd ~/dotfiles
./bootstrap.sh
```

これで完了。詳細は [`./bootstrap.sh`](#bootstrapsh) の項を参照。

---

## 対応 OS

| OS | パッケージマネージャ | メインターミナル |
|---|---|---|
| macOS (Apple Silicon / Intel) | Homebrew | WezTerm |
| Arch Linux (native) | pacman | kitty |
| Arch Linux (WSL) | pacman | (Windows 側 WezTerm) |
| Ubuntu / Debian (native) | apt + curl | kitty |
| Ubuntu / Debian (WSL) | apt + curl | (Windows 側 WezTerm) |

---

## コマンドリファレンス

> 凡例
> - 🟢 **副作用なし**: 何も変更しない (情報表示のみ)
> - 🟡 **限定的な副作用**: 一部のファイルや設定を更新する
> - 🔴 **大きな副作用**: パッケージインストール / シェル変更 / sudo 必要

---

### 初回セットアップ系

新規マシン / 新規環境で「最初の1回だけ」叩くコマンド群。

#### `./bootstrap.sh`

> 🔴 大きな副作用 (パッケージインストール、シェル変更、sudo 要)

**いつ使う?**
- 新規マシンに dotfiles を導入するとき
- リポジトリを clone した直後、最初の1回

**何が起きる?**

1. OS 判定 (macOS / Arch / Ubuntu / WSL)
2. **Linux系のみ** sudo 認証セッションを開始 (5分ごとに自動延長)
3. `just` と `chezmoi` をパッケージマネージャで導入
   - macOS: `brew install just chezmoi`
   - Arch: `sudo pacman -S just chezmoi`
   - Ubuntu: `apt + curl` (just/chezmoi は curl で `~/.local/bin` に取得)
4. `chezmoi init --apply` を実行 (詳しくは下の項目)

**例**

```bash
git clone https://github.com/reisuta/dotfiles ~/dotfiles
cd ~/dotfiles
./bootstrap.sh
```

**所要時間**: パッケージダウンロードがあるため初回は 5〜15 分。

---

#### `chezmoi init --source=$(pwd) --apply`

> 🔴 大きな副作用

**いつ使う?**
- `bootstrap.sh` の中で自動的に呼ばれる (通常は直接叩かない)
- `bootstrap.sh` をスキップして手動で chezmoi を初期化したい場合

**何が起きる?**

1. `~/.config/chezmoi/chezmoi.toml` を生成 (`.chezmoi.toml.tmpl` から)
   - `mode = "symlink"` を設定 → 以降ファイルは symlink で配置される
2. `run_once_before_install-packages.sh.tmpl` 実行 (1回限り)
   - macOS: `brew bundle --file=Brewfile`
   - Arch: `pacman -S` でパッケージ一括インストール
   - Ubuntu: `apt install` + curl で atuin/mise/eza 別途取得
   - 全 OS 共通: oh-my-zsh + powerlevel10k 取得
3. 設定ファイルを **symlink** で配置 (例: `~/.zshrc` → `~/dotfiles/dot_zshrc`)
4. `run_once_after_change-shell.sh.tmpl` 実行 (1回限り)
   - `/etc/shells` に zsh のパスを追加 (必要なら)
   - `chsh -s $(which zsh)` でデフォルトシェル切替

---

### 日常運用系 (chezmoi)

設定変更があった日に叩くコマンド群。symlink モード前提なので **多くの場合 `chezmoi apply` は不要**。

#### `chezmoi diff`

> 🟢 副作用なし

**いつ使う?**
- リポジトリ側の設定を変更した直後、ホーム側に何が反映されるか確認したいとき
- リモートを `git pull` した後、何が変わるか把握したいとき

**何が起きる?**
- ホームディレクトリと chezmoi が想定する状態の差分を表示
- `git diff` 風の出力

**例**

```bash
chezmoi diff
# → 差分が表示される (ターミナルで色分け)
```

---

#### `chezmoi apply`

> 🟡 限定的な副作用

**いつ使う?**
- symlink モードなので **基本的に不要** (リポジトリ編集が即時反映される)
- `.chezmoiignore.tmpl` を変更した時 (除外ルール変更を反映するため)
- 新しい dot_ ファイルを追加した時 (新規 symlink を作るため)
- run_once スクリプトを変更した時 (再実行のため)

**何が起きる?**
- 想定状態と実際の状態が違うファイルだけ symlink を再作成
- 該当する `run_once` スクリプトがあれば実行
- 既に正しい状態のファイルは触らない

**例**

```bash
chezmoi apply -v   # -v で実行内容を詳しく表示
```

---

#### `chezmoi update`

> 🟡 限定的な副作用

**いつ使う?**
- 別マシンで push した変更をこのマシンに取り込みたいとき
- `git pull` + `chezmoi apply` を1コマンドにしたバージョン

**何が起きる?**
1. リポジトリで `git pull --rebase` を実行
2. 続けて `chezmoi apply` を実行

**例**

```bash
chezmoi update -v
```

---

#### `chezmoi edit <ターゲットパス>`

> 🟡 限定的な副作用 (ファイル編集)

**いつ使う?**
- 「`~/.zshrc` を編集する」を意識せずに「`~/.zshrc` を直接編集する感覚で」開きたいとき
- chezmoi に管理させているファイルを編集したいとき

**何が起きる?**
- ターゲットパスから対応するソースパスを逆引き
- nvim でソースファイルを開く (`.chezmoi.toml.tmpl` で `command = "nvim"` を指定)
- 保存して終了するとファイル変更が反映される (symlink モードなので即時)

**例**

```bash
chezmoi edit ~/.zshrc
# → ~/dotfiles/dot_zshrc を nvim で開く
```

---

#### `chezmoi managed`

> 🟢 副作用なし

**いつ使う?**
- chezmoi が今管理しているファイル一覧を見たいとき
- 「これ chezmoi 管理だっけ?」を確認したいとき

**何が起きる?**
- chezmoi が管理しているターゲットパスの一覧表示

**例**

```bash
chezmoi managed
# → .config/nvim/init.lua, .zshrc, .tmux.conf, ...
```

---

#### `chezmoi add <ファイルパス>`

> 🟡 限定的な副作用 (ソースリポジトリにファイル追加)

**いつ使う?**
- ホームディレクトリの既存ファイルを chezmoi 管理下に入れたいとき

**何が起きる?**
- 指定ファイルを `~/dotfiles/` 内に適切な命名規則で配置
- 例: `~/.gitconfig` を追加 → `~/dotfiles/dot_gitconfig` が作られる
- ホーム側のファイルは手付かず (まだ symlink 化はされない)

**例**

```bash
chezmoi add ~/.gitconfig
git -C ~/dotfiles status   # ~/dotfiles/dot_gitconfig が untracked で出る
```

その後 `chezmoi apply` で symlink 化する。

---

### メンテナンス系 (just)

#### `just`  (引数なし)

> 🟢 副作用なし

**いつ使う?**
- 利用可能タスクを忘れたとき
- 何ができるか思い出したいとき

**何が起きる?**
- justfile に定義されているタスクの一覧と説明を表示

**例**

```bash
$ just
Available recipes:
    backup         # 現在の chezmoi 管理状態をアーカイブ (バックアップ)
    brewfile-dump  # 現在のローカル brew 環境から Brewfile を再生成 (macOS 専用)
    doctor         # 環境ヘルスチェック (副作用なし)
    install        # 新規環境の初期セットアップ
    lint           # シェルスクリプトの静的解析
    plugins-update # Neovim プラグインを最新化 (lazy.nvim sync)
    status         # chezmoi 管理対象 + 未管理ファイルの一覧
    test           # 全 OS でテスト (CI 用)
    test-arch      # Arch コンテナで bootstrap を検証
    test-ubuntu    # Ubuntu コンテナで bootstrap を検証
```

---

#### `just install`

> 🔴 大きな副作用 (= `./bootstrap.sh` と同じ)

**いつ使う?**
- `bootstrap.sh` を覚えていないが just は覚えているとき
- `./bootstrap.sh` と機能的には同じ (just 経由で叩いているだけ)

---

#### `just doctor`

> 🟢 副作用なし

**いつ使う?**
- 環境構築直後、ちゃんと揃っているか確認したいとき
- 「コマンドが見つからない」エラーを見たとき
- 別マシンと環境差分が無いか調べたいとき

**何が起きる?**
- 副作用ゼロで以下を確認:
  - OS / WSL / ディストリ判定結果
  - zsh がインストール済 + デフォルトシェル化されているか
  - oh-my-zsh / powerlevel10k の存在
  - コアツール (git/nvim/tmux/fzf/rg/zoxide/bat) の存在
  - オプションツール (eza/fd/atuin/mise/gh) の存在
  - OS別のターミナル (macOS: WezTerm, Arch: kitty)
  - Neovim プラグインのインストール数
  - chezmoi 状態 (pending changes の有無)
- すべて OK なら緑、欠けがあれば赤で表示

**例**

```bash
$ just doctor
==> 環境情報
  OS:     darwin

==> シェル
  ✓ zsh installed: /opt/homebrew/bin/zsh
  ✓ default shell is zsh
  ✓ oh-my-zsh installed
  ✓ powerlevel10k installed

==> コアツール
  ✓ git
  ✓ nvim
  ...
```

---

#### `just test-arch` / `just test-ubuntu` / `just test`

> 🟡 限定的な副作用 (Docker コンテナを起動)

**いつ使う?**
- `bootstrap.sh` や run_once スクリプトを編集した直後、壊れていないか確認したいとき
- 別の OS で動作することを CI 的に検証したいとき

**何が起きる?**
- Docker でクリーンな Arch / Ubuntu コンテナを起動
- リポジトリを read-only でマウント
- 内部で `./bootstrap.sh` を実行
- パッケージインストールから設定配置まで全工程が通るか確認

**前提**
- Docker Desktop / Docker Engine がインストール済みであること

**例**

```bash
just test-arch     # Arch だけ
just test-ubuntu   # Ubuntu だけ
just test          # 両方 (CI 用)
```

---

#### `just plugins-update`

> 🟡 限定的な副作用 (Neovim プラグイン更新)

**いつ使う?**
- Neovim プラグイン (lazy.nvim 管理) を一括更新したいとき

**何が起きる?**
- `nvim --headless "+Lazy! sync" +qa` を実行
- 新規プラグインのインストール / 既存プラグインのアップデート

**例**

```bash
just plugins-update
```

---

#### `just brewfile-dump` (macOS 専用)

> 🟡 限定的な副作用 (Brewfile 上書き)

**いつ使う?**
- 手動で `brew install` した後、それを Brewfile に反映させたいとき
- macOS 環境を真の正としてリポジトリ側を最新化したいとき

**何が起きる?**
- 現在の brew 環境を読み取って `Brewfile` を上書き生成
- `brew bundle dump --file=Brewfile --force` を実行
- 既存の手書きコメントは消える (注意)

**例**

```bash
just brewfile-dump
git -C ~/dotfiles diff Brewfile   # 何が変わったか確認
```

---

#### `just lint`

> 🟢 副作用なし

**いつ使う?**
- `bootstrap.sh` や `scripts/doctor.sh` を編集した後

**何が起きる?**
- shellcheck で `bootstrap.sh` と `scripts/doctor.sh` を静的解析
- `.tmpl` ファイルは chezmoi 処理が必要なので対象外

**前提**
- shellcheck がインストール済 (macOS: `brew install shellcheck`)

---

#### `just backup`

> 🟡 限定的な副作用 (アーカイブ作成)

**いつ使う?**
- 大きな変更前に現状をスナップショット取りたいとき

**何が起きる?**
- `chezmoi archive` でホーム側の管理対象をすべて tar.gz に固める
- ファイル名: `backup-YYYYMMDD-HHMM.tar.gz` (カレント生成)

---

#### `just status`

> 🟢 副作用なし

**いつ使う?**
- chezmoi 全体の状態をざっと見たいとき

**何が起きる?**
- `chezmoi status` (pending な変更) と `chezmoi managed` (管理対象一覧) を続けて表示

---

### 緊急/トラブル対応系

#### `chezmoi apply --force`

> 🔴 大きな副作用 (ホームディレクトリ書き換え)

**いつ使う?**
- 既存ファイルを上書きしてでも chezmoi の想定状態にしたいとき
- 「壊れた状態をリセットしたい」とき

**何が起きる?**
- 通常 `apply` でスキップされる差分も強制適用
- ホーム側のローカル変更は失われる (取り戻せない場合あり)

**注意**: 実行前に `chezmoi diff` で何が起きるか必ず確認すること。

---

#### `chezmoi state delete-bucket --bucket=scriptState`

> 🟡 限定的な副作用 (chezmoi の内部状態リセット)

**いつ使う?**
- `run_once_*` スクリプトを **再度実行したい** とき
- パッケージリストを変えた後、再インストールしたいとき

**何が起きる?**
- chezmoi が「実行済」と覚えている `run_once_*` スクリプトの記録を削除
- 次の `chezmoi apply` で全 run_once スクリプトが再実行される

**例**

```bash
chezmoi state delete-bucket --bucket=scriptState
chezmoi apply -v
# → 全 run_once スクリプトが再走行
```

---

#### `chezmoi forget <ファイルパス>`

> 🟡 限定的な副作用

**いつ使う?**
- ファイルを chezmoi 管理から外したいとき (ファイル自体は残す)

**何が起きる?**
- ソース側 (`~/dotfiles/`) からファイルが消える
- ターゲット側 (`~/.foo`) のファイルは残る (ただの普通のファイルになる)

**例**

```bash
chezmoi forget ~/.gitconfig
```

---

## 状況別チートシート

> 困ったときに「何を叩けばいいか」のクイックリファレンス。

| 状況 | コマンド |
|---|---|
| 新規マシンに導入したい | `./bootstrap.sh` |
| 設定変更を確認したい | `chezmoi diff` |
| ホーム側を最新化したい | `chezmoi apply -v` |
| リモートの変更を取り込みたい | `chezmoi update -v` |
| ファイルを編集したい | `chezmoi edit ~/.zshrc` (or 直接 `~/dotfiles/dot_zshrc` を編集) |
| 環境が正しいか確認したい | `just doctor` |
| 利用可能なタスクを思い出したい | `just` |
| Neovim プラグインを更新したい | `just plugins-update` |
| ホーム既存ファイルを管理下に追加 | `chezmoi add ~/.foo` |
| パッケージリスト変更後、再インストール | `chezmoi state delete-bucket --bucket=scriptState && chezmoi apply -v` |
| 別 OS で壊れていないか試したい | `just test-arch` / `just test-ubuntu` |
| brew で入れたツールを Brewfile に反映 | `just brewfile-dump` (macOS) |
| 設定が壊れた、リセットしたい | `chezmoi diff` で確認 → `chezmoi apply --force` |

---

## ツール棲み分け

```
┌─ bootstrap.sh ─────────────────────────────────────────────┐
│ 唯一の素のシェルスクリプト。                                  │
│ just / chezmoi が未インストールな環境専用のブートストラップ。 │
└─────────────────────────────────────────────────────────────┘
                           ↓ 役目を引き継ぐ
┌─ chezmoi ──────────────────────────────────────────────────┐
│ 設定ファイルの配置 (symlink モード)、OS 別テンプレ分岐、       │
│ 初回パッケージインストール、シェル変更を担当。                 │
│ 日常コマンド: chezmoi diff / apply / update / edit          │
└─────────────────────────────────────────────────────────────┘
                           ↑ 一部のメタタスクで使う
┌─ just ─────────────────────────────────────────────────────┐
│ chezmoi の単純ラッパーは含めない。代わりに以下を担当:           │
│   - just doctor       : 環境健全性チェック                   │
│   - just test-arch    : Arch コンテナで bootstrap 検証       │
│   - just lint         : シェルスクリプト品質チェック          │
│   - just plugins-update: Neovim プラグイン同期               │
│   - just brewfile-dump: 現環境から Brewfile 再生成 (macOS)   │
│   - just backup       : 現状をスナップショット               │
└─────────────────────────────────────────────────────────────┘
```

---

## ディレクトリ構成

```
~/dotfiles/
├── README.md                     ← このファイル
├── bootstrap.sh                  ← 唯一のブートストラップ用シェル
├── justfile                      ← 非ラッパー系タスク集
├── .chezmoi.toml.tmpl            ← chezmoi 自身の設定 (symlink モード等)
├── .chezmoiignore.tmpl           ← OS 別の除外ルール
├── .gitattributes                ← Linguist 言語検出の上書き
├── Brewfile                      ← macOS パッケージリスト
├── archpkgs.txt                  ← Arch ベースパッケージ
├── archpkgs-gui.txt              ← Arch GUI (WSL では除外)
├── aptpkgs.txt                   ← Ubuntu/Debian ベースパッケージ (WSL Ubuntu 用)
│
├── dot_zshrc                     → ~/.zshrc
├── dot_tmux.conf                 → ~/.tmux.conf
├── dot_p10k.zsh                  → ~/.p10k.zsh
├── dot_config/
│   ├── nvim/                     → ~/.config/nvim/
│   ├── kitty/                    → ~/.config/kitty/    (Linux ネイティブのみ)
│   ├── wezterm/                  → ~/.config/wezterm/  (macOS のみ)
│   └── redshift.conf             → ~/.config/redshift.conf (Linux ネイティブのみ)
├── private_dot_local/bin/
│   └── executable_win-clip-copy.sh  → ~/.local/bin/win-clip-copy.sh (WSL のみ)
│
├── run_once_before_install-packages.sh.tmpl  ← chezmoi が apply 前に1度だけ実行
├── run_once_after_change-shell.sh.tmpl        ← chezmoi が apply 後に1度だけ実行
│
├── scripts/
│   └── doctor.sh                 ← `just doctor` の実体
│
└── old/                          ← 退役済みファイル (削除せず保管)
    └── README.md                 ← 中身の説明
```

---

## chezmoi の命名規則 (この repo で使うもの)

| プレフィックス | 効果 |
|---|---|
| `dot_<name>` | `~/.<name>` に配置 |
| `private_<name>` | パーミッション 0600 |
| `executable_<name>` | 実行権限を付与 |
| `run_once_<...>.tmpl` | 1度だけ実行されるスクリプト (内容変更で再実行) |
| `run_once_before_<...>` | apply 前に実行 |
| `run_once_after_<...>` | apply 後に実行 |

組み合わせ可: `private_executable_dot_foo` のように複数プレフィックスを連結できる。
