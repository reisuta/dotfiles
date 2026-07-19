# =============================================================
# dev: プロトコルのハンドラ
#
# Win+R から  dev:dotfiles  のように叩くと、WSL 上の該当ディレクトリを
# nvim で開く。Win キー検索と違い「引数を渡せる」のがこの仕組みの主眼。
#
# 登録は setup-windows-shell.ps1 が行う。
# 受け取る %1 は "dev:dotfiles" のようにスキームを含んだ文字列全体。
# =============================================================
[CmdletBinding()]
param(
    [Parameter(Position = 0)][string]$Uri
)

# --- 設定 --------------------------------------------------
# WSL 側で検索するディレクトリ (前から順に探し、最初に見つかったものを使う)
$SearchDirs = '$HOME $HOME/Programming $HOME/Programming/ruby/rails'

# 使う WSL ディストロ。空文字なら既定のディストロを使う。
$Distro = ''

# 開いたあとに起動するエディタと引数。
# 必ず配列で持つこと。'nvim .' のように 1 つの文字列にすると
# 引数全体が引用符で括られ、「nvim . という名前のコマンド」を探して失敗する。
$Editor     = 'nvim'
$EditorArgs = @('.')
# -----------------------------------------------------------

function Fail {
    param([string]$Message)
    # ハンドラはコンソールを持たないことがあるのでダイアログで通知する
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show($Message, 'dev: ハンドラ') | Out-Null
    exit 1
}

if ([string]::IsNullOrWhiteSpace($Uri)) { Fail '引数がありません。' }

# "dev:name" / "dev://name/" のどちらでも受け取れるように正規化する。
# ブラウザ経由だと後者に変換されることがあるため。
$name = $Uri -replace '^dev:(//)?', ''
$name = $name.TrimEnd('/')
$name = [System.Uri]::UnescapeDataString($name)

if ($name -notmatch '^[A-Za-z0-9._@-]+$') {
    Fail "名前に使えない文字が含まれています: $name"
}

# WSL 側でディレクトリを解決する。
# 二重引用符は使わない: PowerShell 5.1 のネイティブコマンド引数処理で壊れ、
# sh -c に文字列全体が渡らなくなるため。名前は上で検証済みなので空白は入らない。
$finder = 'for d in __DIRS__; do if [ -d $d/__NAME__ ]; then echo $d/__NAME__; exit 0; fi; done; exit 1'
$finder = $finder.Replace('__DIRS__', $SearchDirs).Replace('__NAME__', $name)

$wslArgs = @()
if ($Distro) { $wslArgs += @('-d', $Distro) }

$resolved = & wsl.exe @wslArgs -e sh -c $finder
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($resolved)) {
    Fail "見つかりません: $name`n`n検索対象: $SearchDirs"
}
$resolved = $resolved.Trim()

# エディタが WSL 側に入っているか確認する。
# 未インストールだと起動が即座に終了して「何も起きない」ため、
# その場合はシェルをそのディレクトリで開くだけに落とす。
& wsl.exe @wslArgs -e sh -c "command -v $Editor" | Out-Null
$hasEditor = ($LASTEXITCODE -eq 0)

$inner = @()
if ($Distro) { $inner += @('-d', $Distro) }
$inner += @('--cd', $resolved)
if ($hasEditor) {
    # 各引数を個別の要素として渡す
    $inner += @('--', $Editor) + $EditorArgs
}
# エディタが無ければ '--' 以降を付けず、既定のログインシェルを開く

# 起動する。Windows Terminal があればそちらを優先する
# (wt が無ければ素の conhost になるが動作はする)

if (Get-Command wt.exe -ErrorAction SilentlyContinue) {
    Start-Process wt.exe -ArgumentList (@('wsl.exe') + $inner)
}
else {
    Start-Process wsl.exe -ArgumentList $inner
}
