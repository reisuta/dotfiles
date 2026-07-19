# Windows 側の設定メモ

WSL を主戦場にしている前提で、Windows 側は「薄いホスト層」に留める方針。
ここで管理するのは以下だけ。これ以上踏み込むと労力に対して見返りが落ちる。

1. WSL 自体 (`.wslconfig`)
2. キーボード (Capslock → Ctrl)
3. シェル (`Microsoft.PowerShell_profile.ps1`)
4. アプリ導入 (winget)
5. エクスプローラー等の最低限の UI

## ファイル

| ファイル | 役割 | 管理者権限 |
|---|---|---|
| `setup-windows-registry.ps1` | 表示設定、キーボード、ロングパス | HKLM 部分のみ必要 |
| `setup-windows-shell.ps1` | Win+R、送る、右クリック、`dev:`、スクショ保存先 | 不要 |
| `dev-handler.ps1` | `dev:` プロトコルのハンドラ | 不要 |
| `Microsoft.PowerShell_profile.ps1` | `.zshrc` の Windows 版 | 不要 |
| `../.wslconfig` | WSL2 VM のメモリ配分 | 不要 |

すべて冪等。`-DryRun` で差分だけ確認できる。

## 前提: Windows に Nix は無い

宣言的に書けるのは一部の層だけで、残りは「手で冪等にした命令的スクリプト」になる。
Nix が与えてくれる**再現性とロールバック**は得られず、せいぜい**収束 (convergence)** 止まり。

なので目標は「宣言的にする」ではなく、
**「文書化された手段だけ使い、冪等に、何度でも再実行できる」**に置き替えている。

## レジストリの安定性は4層に分かれる

「レジストリだから不安定」ではない。世間で紹介される手法が T4 に偏っているだけ。

| 層 | 例 | 寿命 |
|---|---|---|
| **T1** documented 拡張点 | App Paths、`Directory\shell` の verb、ProgID、Scancode Map、URL プロトコル | 数十年。サードパーティが依存しているので壊せない |
| **T2** ポリシー | `Policies\*` (ADMX 裏付けあり) | バージョン単位で安定 |
| **T3** 未文書の UI トグル | `Explorer\Advanced` の値 | まちまち。`HideFileExt` は不変、`TaskbarAl` は Win11 で新設 |
| **T4** ハック | CLSID を空で潰すクラシック右クリック | **MS の意図に敵対しており、いずれ壊れる** |

このリポジトリのスクリプトは T4 をひとつだけ含む (クラシック右クリック)。
壊れたらその行を消せば済むようにしてある。

## Win+R が Win キー検索に勝てる領域

単純な exe 起動は検索の方が速い。Win+R の価値は「検索に出ないもの」と「引数を渡せること」。

### `shell:` — 検索では出ないフォルダ

```
shell:startup           スタートアップ (ログオン時自動起動)
shell:sendto            「送る」の中身
shell:AppsFolder        UWP 含む全アプリ。ここから UWP のショートカットが作れる
shell:common startup    全ユーザーのスタートアップ
shell:RecycleBinFolder  ごみ箱
shell:UserProfiles      C:\Users
```

### `.cpl` / `.msc` — 設定アプリに埋もれた旧コンパネと管理ツール

```
ncpa.cpl        ネットワークアダプタ (設定アプリからの到達が異様に面倒)
sysdm.cpl       システムのプロパティ → 環境変数
powercfg.cpl    電源プラン
appwiz.cpl      プログラムと機能
mmsys.cpl       サウンド

services.msc    サービス
devmgmt.msc     デバイスマネージャ
diskmgmt.msc    ディスクの管理
taskschd.msc    タスクスケジューラ
eventvwr.msc    イベントビューア
gpedit.msc      ローカルグループポリシー (Pro のみ)
```

### `ms-settings:` — 設定アプリのディープリンク

`ms-settings:display` / `ms-settings:network` など。

### カスタムプロトコル — 引数を渡せる唯一の手段

`dev-handler.ps1` がこれ。`Win+R → dev:dotfiles` で WSL の該当ディレクトリを nvim で開く。
App Paths は引数を取れないので、踏み込むならこちら。

ただし引数付きランチャーが欲しいだけなら **PowerToys Run / Flow Launcher の方が UX は上**。
カスタムプロトコルの利点は「追加ソフト無しで OS 標準機能だけで完結する」点にある。

## 意図的に自動化していないもの

### エクスプローラーの詳細表示の「列」

`HKCU:\Software\Classes\Local Settings\...\Bags` にフォルダごとの状態が
**不透明なバイナリ**で散らばる構造で、版管理に耐えない。

代わりに `FolderType=NotSpecified` だけ設定し、
「勝手に画像/音楽レイアウトへ切り替わる」挙動の抑止に留めている。

### Win+X メニュー

`%LOCALAPPDATA%\Microsoft\Windows\WinX\` に `.lnk` を置く構造だが、
**特殊なハッシュが押されていない `.lnk` は無視される** (`hashlnk` という外部ツールが必要)。
改造を防ぐために意図的にそうなっている T4 の典型。触らない。

### Win+<英字> のショートカット

ほぼ MS が予約済みで、ユーザー定義の口が無い。
`.lnk` のプロパティの「ショートカットキー」は **Ctrl+Alt+<キー> しか受け付けない**。

現実解は PowerToys Keyboard Manager (設定が JSON なので版管理可能) か AutoHotkey。

## 導入を検討しているもの

### Mac の Quick Look (Space プレビュー) 相当

Windows 標準には無い。

| | キー | 出自 | 設定の版管理 |
|---|---|---|---|
| PowerToys Peek | Ctrl+Space | Microsoft 製 | `~/AppData/Local/Microsoft/PowerToys/` に JSON → 可 |
| QuickLook | **Space 単独** | サードパーティ (OSS) | 限定的 |

```powershell
winget install Microsoft.PowerToys   # Peek 含む
winget install QL-Win.QuickLook      # Space 単独キー
```

標準機能ではエクスプローラーのプレビューウィンドウ (Alt+P) が近いが、
常時表示のペインなので Space トグルとは体験が別物。

### WinGet Configuration (DSC)

`aptpkgs.txt` / `Brewfile` の Windows 版として一番筋が良い。
冪等性・依存順序・差分検出を処理系側が見てくれる。

```yaml
properties:
  resources:
    - resource: Microsoft.WinGet.DSC/WinGetPackage
      settings: { id: Microsoft.WindowsTerminal, ensure: Present }
  configurationVersion: 0.2.0
```

## ハマりどころ

### `.ps1` は UTF-8 BOM 付きで保存する

Windows PowerShell 5.1 は **BOM が無いファイルを ANSI として読む**ため、
日本語コメントが化けて構文エラーになる。PowerShell 7 なら問題ない。

編集時に BOM を落とさないよう注意。

### `$PROFILE` のパスは決め打ちしない

| 環境 | パス |
|---|---|
| Windows PowerShell 5.1 | `~\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1` |
| PowerShell 7 | `~\Documents\PowerShell\Microsoft.PowerShell_profile.ps1` |

さらに **Documents が OneDrive にリダイレクトされていると `~\OneDrive\Documents\...` に化ける**。
必ず `$PROFILE` を評価して確認すること。

### WSL 上のファイルへシンボリックリンクを張らない

`\\wsl$` 越しのアクセスは遅く、WSL 停止中は参照そのものが失敗する。
プロファイルもハンドラも Windows 側にコピーして使う。

### PowerShell の名前解決順は Alias → Function → Cmdlet

**組み込み alias が自作 function より優先される。**
例えば `gci` は既定で `Get-ChildItem` のエイリアスなので、
`function gci` を書いても効かない。先に `Remove-Item Alias:gci` する必要がある。

### 反映タイミングがバラバラ

| 設定 | 反映 |
|---|---|
| エクスプローラー表示、右クリック | explorer 再起動 |
| キーリピート、マウス | 再ログオン |
| Capslock → Ctrl、ロングパス、`.wslconfig` | 再起動 (`.wslconfig` は `wsl --shutdown`) |
