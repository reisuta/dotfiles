# Windows 側の設定メモ

WSL を主戦場にしている前提で、Windows 側は「薄いホスト層」に留める方針。
ここで管理するのは以下だけ。これ以上踏み込むと労力に対して見返りが落ちる。

1. WSL 自体 (`.wslconfig`)
2. キーボード (Capslock → Ctrl)
3. シェル (`Microsoft.PowerShell_profile.ps1`)
4. アプリ導入 (winget)
5. エクスプローラー等の最低限の UI
6. ウィンドウ管理 (GlazeWM + Zebar + Flow Launcher)

6 は上の方針からの意図的な逸脱。Windows で作業する時間が無視できなくなり、
Sway の操作感がそのまま使えないコストの方が大きくなったため入れた。
ここから先 (アイコンテーマ、シェル置換、Explorer の全面改造) には踏み込まない。

## ファイル

| ファイル | 役割 | 管理者権限 |
|---|---|---|
| `setup-windows-registry.ps1` | 表示設定、キーボード、ロングパス | HKLM 部分のみ必要 |
| `setup-windows-shell.ps1` | Win+R、送る、右クリック、`dev:`、スクショ保存先 | 不要 |
| `setup-windows-tiling.ps1` | GlazeWM / Zebar / Flow Launcher の導入と配置 | 不要 |
| `windows-tiling/` | 上が配置する設定ファイルの実体 | — |
| `dev-handler.ps1` | `dev:` プロトコルのハンドラ | 不要 |
| `Microsoft.PowerShell_profile.ps1` | `.zshrc` の Windows 版 | 不要 |
| `../.wslconfig` | WSL2 VM のメモリ配分 | 不要 |

すべて冪等。`-DryRun` で差分だけ確認できる。

## タイリング環境 (`setup-windows-tiling.ps1`)

Arch の Sway 環境を Windows 側で再現する。対応関係は以下。

| Linux | Windows | 設定ファイル |
|---|---|---|
| sway | GlazeWM | `windows-tiling/glazewm/config.yaml` |
| waybar | Zebar | `windows-tiling/zebar/tokyo-night/` (HTML/CSS) |
| rofi | Flow Launcher | `windows-tiling/flow-launcher/Tokyo Night.xaml` |
| yazi | Files | (アプリ側の設定のみ) |
| swaybg | 静止画壁紙 | `windows-tiling/make-wallpaper.ps1` で生成 |

### キーバインドは Sway に合わせてある

`dot_config/sway/config` が正。**modifier だけ `Mod4` → `alt` に読み替え、
キー配列と割当ては同一**にしてある。

Super のまま持ってこられない理由は `Win+L` ひとつ。Sway の `$mod+l` は
「フォーカス上」だが、Windows の `Win+L` はロックで、winlogon がキーボード
フックより下の層で握っているため GlazeWM から奪えない。押すたびに画面が
ロックされることになる。`Win+D` や `Win+E` は GlazeWM が奪えるのでこれだけが例外。

`HKLM` の `DisableLockWorkstation` を立てれば `Win+L` 自体を殺して Super を
使えるが、ロック機能を失う対価に見合わないので採らなかった。

Sway にあって GlazeWM に無いもの (`layout stacking` / `tabbed`、`focus parent`) は
未割当。詳細は `config.yaml` の冒頭コメントに対応表がある。

### 引っかかりどころ

**Zebar のローカルパック ID はディレクトリ名そのもの。**
`local.<名前>` と書くと `No widget pack found` になる。
公式スターターは `Program Files` 配下にあり書き換えられないので、
`~/.glzr/zebar/<名前>/` に `zpack.json` を置いて自作パックにしている。

**Zebar の JS は CDN から実行時に読ませない。**
公式スターターは `zebar` に加えて React と Babel まで CDN から読む作りだが、
これはバーの文脈で第三者のコードが動く経路になる。バーは `glazewm` プロバイダを
握っており WM コマンドを実行できるうえ、動的 import なので SRI も付けられない。

React と Babel は捨てて素の JS に書き直し、`zebar` 本体は取得時点のものを
`zebar/tokyo-night/vendor/` に固定した。副作用としてオフラインでも描画される。

**ただし取得物そのものはリポジトリに入れていない。**
zebar は GPL-3.0-only、luxon は MIT、@tauri-apps/api は Apache-2.0 OR MIT で、
いずれも再配布には著作権表示の保持が要るが、**esm.sh のミニファイ版はその表示を
削ぎ落としている**ため条件を満たせない。zebar は GPL なのでさらに重い。
そこで版管理するのは取得スクリプトと期待ハッシュ (`vendor/SHA256SUMS`) だけにし、
`.mjs` は各自の環境で取得する形にした。配布行為が発生しないので問題が生じず、
セキュリティ上の目的はそのまま維持できる。

`setup-windows-tiling.ps1` は未取得・ハッシュ不一致を検出したら
`vendor-zebar.ps1` を呼び、**検証に通ったものだけを配置する**。
不一致のまま配置すると固定した意味が無くなるので、そこで失敗させている。

なお esm.sh の `?bundle` / `?standalone` / `?bundle-deps` はどれも依存を
インライン化せず `/luxon@...` を絶対パスで参照したまま返してくるため、
参照を再帰的に辿って書き換えている。luxon がエントリごとに全体入りで配信される
関係で 600KB 強になるが、大半は同一内容の重複。

**第三者コードを取り込むときはライセンスを確認すること。**
「秘密情報が無い」ことと「再配布してよい」ことは別問題で、
このリポジトリは公開されているため後者も満たす必要がある。

**タスクバーの自動非表示はレジストリで書いても消える。**
`StuckRects3` の `byte[8] bit0` を立てる方法が広く紹介されているが、
explorer が起動時・終了時に自分の状態を書き戻すため潰される。
`SHAppBarMessage(ABM_SETSTATE, ABS_AUTOHIDE)` を叩くのが確実。

**Flow Launcher は終了時に `Settings.json` を書き戻す。**
起動中に編集しても捨てられるので、必ずプロセスを止めてから触る。

**Zebar は provider の更新を毎回 INFO で標準出力に吐く。**
実測で 15 秒あたり約 18KB (時間あたり 4MB 強)。すべて stdout で stderr には出ない。
CLI にログレベルの指定は無く、`LOG_LEVEL` / `RUST_LOG` を設定しても変わらない
(バイナリ内にこれらの文字列はあるが、埋め込まれた別クレートのもの)。

ログイン時に GlazeWM の `startup_commands` から起動される正常系では標準出力の
行き先が無いので問題にならないが、**コンソールから `Start-Process zebar` すると
その端末を埋め尽くす**。手で起動し直したいときは GlazeWM に起動させること。

```powershell
& 'C:\Program Files\glzr.io\GlazeWM\cli\glazewm.exe' command shell-exec zebar
```

**GlazeWM のプロセスは `Stop-Process` で落ちないことがある。**
CLI 経由の IPC (`glazewm.exe command wm-exit`) なら確実に終了する。
設定の再読み込みも `glazewm.exe command wm-reload-config` で足りる (再起動不要)。

**Files は .NET Desktop Runtime 10 が無いと無言で起動失敗する。**
プロセスも window も作られず、ブラウザでダウンロードページが開くだけなので
原因が分かりにくい。`Microsoft.DotNet.DesktopRuntime.10` を依存として
パッケージリストに入れてある。

**`Files_1y0xx7n9077q4!App` は全マシン共通の定数。**
MSIX の PackageFamilyName の後半は発行者文字列から決まるハッシュで、
インストールごとに変わる値ではない。公開リポジトリに入れて問題ない
(上記「安全/危険」の判断基準では「安全」側)。

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

## 公開リポジトリに入れる前の確認

このリポジトリは公開されている。Windows の設定は
**GUID や 16 進バイナリという「見た目が機密っぽい値」**を大量に含むため、
何が安全で何が危険かを取り違えないこと。

判断基準はひとつ。**その値が「全マシン共通の定数」か「この環境で生成された固有値」か。**
見た目が暗号鍵じみているかどうかは判断材料にならない。

### 安全（Microsoft が定義した定数。全マシンで同一）

| 種類 | 例 | 用途 |
|---|---|---|
| CLSID / IID | `86ca1aa0-34aa-4e8b-a509-50c905bae2a2` | Win11 コンテキストメニューハンドラ |
| KNOWNFOLDERID | `b7bede81-df94-4682-a7d8-57a52620b86f` | `FOLDERID_Screenshots` |
| スキャンコード | `1D` = 左Ctrl / `3A` = CapsLock | Scancode Map |

`Scancode Map` の `00 00 00 00 ... 02 00 00 00 1D 00 3A 00 ...` は
**「CapsLock を左Ctrl に割り当てる」以上の情報を持たない**。
ヘッダ・エントリ数・変換ペアという文書化された構造で、環境依存の値は入らない。
不透明な 16 進に見えるが、実際のエントロピーはほぼゼロ。

### 危険（環境固有に生成される。絶対にコミットしない）

| 種類 | 場所 | 漏れる情報 |
|---|---|---|
| MachineGuid | `HKLM\SOFTWARE\Microsoft\Cryptography` | インストール単位で一意。追跡子になる |
| SID | `S-1-5-21-...` | ローカル/ドメインのアカウントを特定 |
| Azure / Entra のテナント ID・サブスクリプション ID | — | 組織を特定 |
| プロダクト ID、デジタルライセンス | — | ライセンス実体 |
| LSA シークレット、SAM、DPAPI マスターキー | `HKLM\SECURITY`、`HKLM\SAM` | 認証情報そのもの |
| ボリューム GUID、MDM 登録 ID | — | ハードウェア/管理下の識別 |

### 特に注意: バイナリ値は中身に個人情報が入りうる

`Bags` / `BagMRU`、`ComDlg32\LastVisitedPidlMRU`、`RecentDocs` などは
**フォルダ構成やファイル名の履歴が丸ごと埋まっている**。
「エクスプローラーの列設定を持ち回るために Bags をエクスポートする」案が
筋悪なのは、版管理に耐えないという理由だけでなく、
**ディレクトリ構成が公開リポジトリに漏れる**ためでもある。

### コミット前のスキャン

認証情報のパターンだけでは GUID を拾えない。両方を走らせること。

```sh
# 認証情報・個人パス
grep -rn -i -e password -e secret -e token -e api_key -e private_key \
  -e ssh-rsa -e AKIA -e ghp_ -e github_pat -e Bearer -e credential \
  -e /home/ -e /mnt/c -e '@gmail' .

# GUID の全数確認（ヒットしたら上表のどちらかに分類する）
grep -rnoE '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}' .

# 自分の MachineGuid / SID が混入していないかの直接確認（PowerShell 側）
#   (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Cryptography').MachineGuid
#   ([Security.Principal.WindowsIdentity]::GetCurrent()).User.Value
```

なお `IntPtr hToken`（`SHSetKnownFolderPath` の引数名）は
`token` パターンに引っかかるが誤検出。API のシグネチャなので問題ない。

## 実機検証で判明したこと

Windows 11 25H2 / build 26200.8875 / RAM 8GB の実機に適用して確認した内容。

### `HKCU\Software\Policies` は HKCU でも管理者権限が要る

`DisableSearchBoxSuggestions` を標準ユーザーで適用しようとすると
`Access to the registry key ... is denied` で失敗する。
Policies ブランチはグループポリシーの管理下にあり ACL で保護されているため。
**「HKCU だから管理者不要」は成り立たない。** 管理者セクションに置くこと。

あわせて `Set-Reg` に try/catch を入れ、1 項目の失敗で
スクリプト全体が中断しないようにした (`$ErrorActionPreference = 'Stop'` のため
以前は途中で止まり、サマリも explorer 再起動も実行されなかった)。

### `TaskbarDa` だけ同じキーの中で書き込めない

`Explorer\Advanced` は標準ユーザーで書けるキーだが、**`TaskbarDa` (ウィジェット非表示)
への書き込みだけ `UnauthorizedAccessException` になる**。同じキーの
`ShowTaskViewButton` は同一プロセス・同一権限で問題なく書ける。

```
Set-ItemProperty ...\Advanced -Name TaskbarDa          -Value 0   # 失敗
Set-ItemProperty ...\Advanced -Name ShowTaskViewButton -Value 0   # 成功
```

レジストリの ACL は本来キー単位なので、値単位で弾かれる理由は特定できていない
(この環境では既定値が `0` で、`Set-Reg` は `[skip]` に倒れるため実害は出ていない)。
値が `1` の環境では `setup-windows-registry.ps1` の該当行が失敗としてカウントされる。
その場合は「ウィジェットは設定アプリから手で切る」に落とすこと。

### `$PROFILE` は実際に OneDrive へリダイレクトされていた

```
C:\Users\<user>\OneDrive\ドキュメント\WindowsPowerShell\Microsoft.PowerShell_profile.ps1
```

`~\Documents\...` を決め打ちしていたら配置に失敗していた。必ず `$PROFILE` を評価する。
なお OneDrive 配下なのでプロファイルは自動的に同期される。秘密情報を書かないこと。

### `Get-Command` は「見つからない」ときが最も高コスト

プロファイル起動が遅い原因の大半がこれだった。単一プロセス内での実測値:

| 処理 | 時間 |
|---|---|
| `Get-Command` × 3 (未インストールのツール) | **1,458 ms** |
| PATH を直接走査する `Test-Exe` × 3 | **44 ms** |
| `Get-Module -ListAvailable PSReadLine` | 286 ms |

全コマンド種別と PATHEXT を総当たりするため、不在の判定に最も時間がかかる。
`[System.IO.File]::Exists` で PATH を直接見る方式へ変更し、
PSReadLine は存在確認をやめて try/catch に変えた。

プロファイル読み込み時間: **中央値 1,785 ms → 675 ms (約 2.6 倍)**

計測はプロセス起動の差分ではなく、単一プロセス内で `Measure-Command { . $prof }`
を使うこと。プロセス起動は分散が大きく (同条件で 2,298〜2,461 ms)、
1 秒規模の改善が埋もれて見えなくなる。

### WSL に渡すコマンドは引数ごとに分割する

`'nvim .'` のように 1 つの文字列で渡すと全体が引用符で括られ、
WSL は「`nvim .` という名前のコマンド」を探して失敗する。

```powershell
# 誤り
$inner += @('--cd', $path, '--', 'nvim .')
# 正しい
$inner += @('--cd', $path, '--', 'nvim', '.')
```

さらに、起動先のコマンドが**未インストールでも何も起きないだけ**で
エラーが表示されない。`dev-handler.ps1` は
`command -v` で存在確認し、無ければシェルを開くだけに落とすようにした。

### Windows Terminal は既存ウィンドウに「タブ」を開く

そのため `Get-Process WindowsTerminal` の数で起動成否を判定してはいけない。
検証には副作用の残る方法を使うこと。

```powershell
# 動作確認の定石: ファイルを書かせて中身を見る
Start-Process wt.exe -ArgumentList 'wsl.exe','--cd','/path','--','sh','-c','pwd > /tmp/t.txt'
```

`wt.exe` は `--` 以降を正しく透過することを確認済み。

### 冪等性は実機で確認済み

2 回目の実行で「変更: 0 件 / 変更なし: 16 件 / 失敗: 0 件」となることを確認。
