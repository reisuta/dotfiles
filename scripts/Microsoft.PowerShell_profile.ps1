# =============================================================
# PowerShell プロファイル (dot_zshrc の Windows 版)
#
# 配置方法:
#   # 配置先の確認 (OneDrive リダイレクトがあるとパスが変わるため必ず評価する)
#   $PROFILE
#
#   # コピーして配置
#   New-Item -ItemType Directory -Force -Path (Split-Path $PROFILE) | Out-Null
#   Copy-Item .\scripts\Microsoft.PowerShell_profile.ps1 $PROFILE -Force
#
# WSL 内のファイルへシンボリックリンクを張るのは避けること。
# \\wsl$ 越しのアクセスは遅く、WSL 停止中はシェル起動が失敗する。
#
# 日本語コメントを含むため UTF-8 BOM 付きで保存すること。
# Windows PowerShell 5.1 は BOM が無いと ANSI として読み、文字化けする。
# =============================================================

# -------------------------------------------------------------
# 実行ファイルの存在判定
#
# Get-Command は全コマンド種別と PATHEXT を総当たりするため、
# 「見つからない」場合が最も高コストになる (実測: 3 件で約 1.8 秒)。
# PATH を直接走査する方が桁違いに速い。
# -------------------------------------------------------------

$script:PathDirs = @($env:PATH -split ';' | Where-Object { $_ })
$script:PathExts = @('.exe', '.cmd', '.bat')

function Test-Exe {
    param([Parameter(Mandatory)][string]$Name)
    foreach ($dir in $script:PathDirs) {
        foreach ($ext in $script:PathExts) {
            if ([System.IO.File]::Exists("$dir\$Name$ext")) { return $true }
        }
    }
    return $false
}

# -------------------------------------------------------------
# 外部ツールの初期化 (zsh 側と同じものを使う)
#   starship.toml は ~/.config/starship.toml をシェル非依存で共有できる
# -------------------------------------------------------------

if (Test-Exe 'starship') { Invoke-Expression (&starship init powershell) }
if (Test-Exe 'zoxide')   { Invoke-Expression (& { (zoxide init powershell | Out-String) }) }
if (Test-Exe 'mise')     { Invoke-Expression (& { (mise activate pwsh | Out-String) }) }

# -------------------------------------------------------------
# PSReadLine (zsh の補完体験に寄せる)
# -------------------------------------------------------------

# Get-Module -ListAvailable は全モジュールパスを走査するため遅い (実測 約 0.6 秒)。
# 存在確認はせず、失敗を握り潰す方が速い。
try {
    Set-PSReadLineOption -EditMode Windows
    Set-PSReadLineOption -HistoryNoDuplicates
    Set-PSReadLineOption -HistorySearchCursorMovesToEnd

    # 予測候補。PSReadLine 2.2 未満では失敗するので段階的に落とす
    try {
        Set-PSReadLineOption -PredictionSource HistoryAndPlugin
        Set-PSReadLineOption -PredictionViewStyle ListView
    }
    catch {
        try { Set-PSReadLineOption -PredictionSource History } catch {}
    }

    # 上下キーで「打ちかけの文字列に前方一致する履歴」を辿る
    Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
}
catch {
    # PSReadLine が無い環境 (ISE 等) では何もしない
}

# -------------------------------------------------------------
# 組み込みエイリアスの退避
#
# PowerShell の解決順は Alias -> Function -> Cmdlet。
# 組み込み alias が自作 function より優先されるため、先に消す必要がある。
# 例: gci は既定で Get-ChildItem のエイリアス。
# -------------------------------------------------------------

$script:MyCommands = @(
    'n', 'g', 'gst', 'gdd', 'gci', 'gbr', 'gdf', 'glg',
    'd', 'dc', 'dcb', 'dcu', 'dcd',
    'la', 'll', 'l', 'cc', 'gr', 'e', 'which',
    'np', 'ni', 'doc', 'desk', 'down'
)

foreach ($name in $script:MyCommands) {
    if (Test-Path "Alias:$name") {
        Remove-Item "Alias:$name" -Force -ErrorAction SilentlyContinue
    }
}

# -------------------------------------------------------------
# エディタ / Git / Docker
#   引数を伴うものは Set-Alias では書けないため関数で定義する
# -------------------------------------------------------------

function n { nvim @args }

function g   { git @args }
function gst { git status @args }
function gdd { git add . }
function gci { git commit -m @args }
function gbr { git branch @args }
function gdf { git diff @args }
function glg { git log --oneline --graph --decorate @args }

function d   { docker @args }
function dc  { docker compose @args }
function dcb { docker compose build @args }
function dcu { docker compose up @args }
function dcd { docker compose down @args }

# -------------------------------------------------------------
# ファイル操作 / 移動
# -------------------------------------------------------------

function la { Get-ChildItem -Force @args }
function ll { Get-ChildItem @args | Format-Table -AutoSize }
function cc { Clear-Host }
function ..   { Set-Location .. }
function ...  { Set-Location ../.. }

# エクスプローラーで現在地を開く
function e { explorer.exe $(if ($args.Count) { $args[0] } else { '.' }) }

function which { Get-Command @args }

# grep -r --line-number --color 相当
function gr {
    param([Parameter(Mandatory)][string]$Pattern, [string]$Path = '.')
    Get-ChildItem -Path $Path -Recurse -File | Select-String -Pattern $Pattern
}

# ページャ。less があれば使い、無ければ標準のページングに落とす
function l {
    if (Test-Exe 'less') { less @args }
    else { Get-Content @args | Out-Host -Paging }
}

# -------------------------------------------------------------
# 設定ファイルへのショートカット (zsh の nz / ni / .z に相当)
# -------------------------------------------------------------

function np { nvim $PROFILE }                              # プロファイルを編集
function ni { nvim "$env:LOCALAPPDATA\nvim\init.lua" }     # nvim 設定を編集 (Windows のパス)
function .p { . $PROFILE }                                 # プロファイルを再読み込み

# -------------------------------------------------------------
# よく使うディレクトリ
#   WSL 側のパス依存エイリアス (literature / memo / Screenshot 等) は
#   Windows には存在しないため移植していない。
# -------------------------------------------------------------

function doc  { Set-Location ([Environment]::GetFolderPath('MyDocuments')) }
function desk { Set-Location ([Environment]::GetFolderPath('Desktop')) }
function down { Set-Location (Join-Path $env:USERPROFILE 'Downloads') }

# -------------------------------------------------------------
# 既定の挙動
# -------------------------------------------------------------

# UTF-8 で出力する (日本語まわりの文字化け対策)
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
