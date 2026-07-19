#Requires -Version 5.1
<#
.SYNOPSIS
    シェル統合まわりのカスタマイズ。Win+R エイリアス、送る、右クリック、
    dev: プロトコル、スクリーンショット保存先。

.DESCRIPTION
    setup-windows-registry.ps1 が「表示設定」を担うのに対し、
    こちらは「操作の入口を増やす」側を担う。

    すべて HKCU 配下または既知フォルダ API のみを使うため管理者権限は不要。
    いずれも文書化された拡張点 (T1) なので、Windows の更新で壊れにくい。

.PARAMETER ScreenshotDir
    Win+PrtScn の保存先。指定したときだけ変更する。省略時は何もしない。

.PARAMETER HandlerPath
    dev: プロトコルのハンドラ (dev-handler.ps1) の場所。
    省略時はこのスクリプトと同じディレクトリを見る。

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\setup-windows-shell.ps1 -DryRun

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\setup-windows-shell.ps1 `
        -ScreenshotDir 'C:\Users\me\Pictures\SS'
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [string]$ScreenshotDir,
    [string]$HandlerPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Changed = 0
$script:Skipped = 0

function Write-Section { param([string]$T) Write-Host ''; Write-Host "== $T" -ForegroundColor Cyan }
function Note-Set  { param([string]$M) Write-Host "    [set ] $M" -ForegroundColor Yellow; $script:Changed++ }
function Note-Skip { param([string]$M) Write-Host "    [skip] $M" -ForegroundColor DarkGray; $script:Skipped++ }

Write-Host ''
Write-Host '--- Windows シェル統合 ---' -ForegroundColor Green
if ($DryRun) { Write-Host '  DryRun: 書き込みは行いません' -ForegroundColor Magenta }

# =============================================================
# 1. Win+R エイリアス (App Paths)
#
#    単純な exe 起動は Win キー検索の方が速いので、ここに置く価値があるのは
#    「検索に出てこない実体」や「名前を短くしたいもの」に限られる。
# =============================================================

Write-Section 'Win+R エイリアス (App Paths)'

$appAliases = @{
    # 'エイリアス名' = '実行ファイルのフルパス'
    'code' = "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe"
    'ff'   = "$env:ProgramFiles\Mozilla Firefox\firefox.exe"
}

$appPathsBase = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths'

foreach ($alias in $appAliases.Keys) {
    $exe = $appAliases[$alias]
    if (-not (Test-Path $exe)) { Note-Skip "$alias (実体が無い: $exe)"; continue }

    $key = Join-Path $appPathsBase "$alias.exe"   # キー名は .exe で終わらせる
    $cur = if (Test-Path $key) { (Get-ItemProperty $key).'(default)' } else { $null }
    if ($cur -eq $exe) { Note-Skip "$alias"; continue }

    Note-Set "$alias -> $exe"
    if (-not $DryRun) {
        New-Item $key -Force -Value $exe | Out-Null
        Set-ItemProperty $key 'Path' (Split-Path $exe)
    }
}

# =============================================================
# 2. 「送る」メニュー (shell:sendto)
#
#    SendTo は選択中のパスを最終引数として渡す。
#    wsl.exe --cd は Windows パスも受け付けるので、追加の仲介スクリプトが要らない。
# =============================================================

Write-Section '「送る」メニュー'

$sendTo = [Environment]::GetFolderPath('SendTo')

$sendToItems = @(
    @{ Name = 'WSL でここを開く'; Target = 'wsl.exe'; Arguments = '--cd' }
)

foreach ($item in $sendToItems) {
    $lnkPath = Join-Path $sendTo ($item.Name + '.lnk')
    if (Test-Path $lnkPath) { Note-Skip $item.Name; continue }

    Note-Set $item.Name
    if (-not $DryRun) {
        $ws = New-Object -ComObject WScript.Shell
        $lnk = $ws.CreateShortcut($lnkPath)
        $lnk.TargetPath = $item.Target
        $lnk.Arguments  = $item.Arguments
        $lnk.Save()
    }
}

# =============================================================
# 3. 右クリックメニューへの項目追加
#
#    Directory            = フォルダを直接右クリック (%1 にそのフォルダ)
#    Directory\Background = フォルダ内の余白を右クリック (%V に現在地)
#    両方に登録しないと片方でしか出ないので注意。
# =============================================================

Write-Section '右クリックメニュー'

$verbs = @(
    @{ Key = 'Directory\shell\OpenWSL';            Label = 'ここで WSL を開く'; Command = 'wsl.exe --cd "%1"' }
    @{ Key = 'Directory\Background\shell\OpenWSL'; Label = 'ここで WSL を開く'; Command = 'wsl.exe --cd "%V"' }
)

foreach ($verb in $verbs) {
    $key = "HKCU:\Software\Classes\$($verb.Key)"
    if (Test-Path $key) { Note-Skip $verb.Key; continue }

    Note-Set $verb.Key
    if (-not $DryRun) {
        New-Item $key -Force -Value $verb.Label | Out-Null
        Set-ItemProperty $key 'Icon' 'wsl.exe'
        New-Item "$key\command" -Force -Value $verb.Command | Out-Null
    }
}

# =============================================================
# 4. dev: プロトコル
#
#    Win+R に「引数を渡せる入口」を作る。Win キー検索にはできない芸当。
#      Win+R -> dev:dotfiles  で WSL の ~/dotfiles を nvim で開く
# =============================================================

Write-Section 'dev: プロトコル'

if (-not $HandlerPath) {
    $HandlerPath = Join-Path $PSScriptRoot 'dev-handler.ps1'
}

if (-not (Test-Path $HandlerPath)) {
    Note-Skip "dev-handler.ps1 が見つからない ($HandlerPath)"
}
elseif ($HandlerPath -like '\\wsl*' -or $HandlerPath -like '\\\\wsl*') {
    # WSL 上のファイルを直接指すと、WSL 停止中に起動が失敗し、常に低速になる
    Write-Host '    [warn] ハンドラが WSL 上にあります。Windows 側にコピーしてください。' -ForegroundColor Red
    $script:Skipped++
}
else {
    $schemeKey = 'HKCU:\Software\Classes\dev'
    $command = '"' + (Get-Process -Id $PID).Path + '" -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $HandlerPath + '" "%1"'

    $curCmd = $null
    if (Test-Path "$schemeKey\shell\open\command") {
        $curCmd = (Get-ItemProperty "$schemeKey\shell\open\command").'(default)'
    }

    if ($curCmd -eq $command) { Note-Skip 'dev: は登録済み' }
    else {
        Note-Set "dev: -> $HandlerPath"
        if (-not $DryRun) {
            New-Item $schemeKey -Force -Value 'URL:dev protocol' | Out-Null
            Set-ItemProperty $schemeKey 'URL Protocol' ''
            New-Item "$schemeKey\shell\open\command" -Force -Value $command | Out-Null
        }
    }
}

# =============================================================
# 5. スクリーンショット保存先 (FOLDERID_Screenshots)
#
#    User Shell Folders を直接書き換える方法が広く出回っているが、
#    あれは既存ファイルを移動せず整合性が崩れることがある。
#    正式な API である SHSetKnownFolderPath を使う。
# =============================================================

Write-Section 'スクリーンショット保存先'

if (-not $ScreenshotDir) {
    Note-Skip '-ScreenshotDir 未指定のため変更しない'
}
else {
    $signature = @'
[DllImport("shell32.dll")]
public static extern int SHSetKnownFolderPath(
    ref Guid rfid, uint dwFlags, IntPtr hToken,
    [MarshalAs(UnmanagedType.LPWStr)] string pszPath);
'@

    Note-Set "Win+PrtScn の保存先 -> $ScreenshotDir"
    if (-not $DryRun) {
        New-Item -ItemType Directory -Force -Path $ScreenshotDir | Out-Null

        $kf = Add-Type -MemberDefinition $signature -Name KnownFolder -Namespace Shell -PassThru
        $guid = [Guid]'b7bede81-df94-4682-a7d8-57a52620b86f'   # FOLDERID_Screenshots
        $rc = $kf::SHSetKnownFolderPath([ref]$guid, 0, [IntPtr]::Zero, $ScreenshotDir)

        if ($rc -ne 0) { Write-Error ("SHSetKnownFolderPath が失敗しました: 0x{0:X8}" -f $rc) }
        else { Write-Host '           既存ファイルは移動しません。必要なら手動で移してください。' -ForegroundColor DarkGray }
    }
}

# =============================================================

Write-Host ''
Write-Host ("変更: {0} 件 / 変更なし: {1} 件" -f $script:Changed, $script:Skipped) -ForegroundColor Green

if ($DryRun) {
    Write-Host 'DryRun のため何も書き込んでいません。' -ForegroundColor Magenta
    return
}

if ($script:Changed -gt 0) {
    Write-Host ''
    Write-Host '右クリックメニューの反映には explorer の再起動が必要な場合があります。' -ForegroundColor Gray
    Write-Host '  Stop-Process -Name explorer -Force' -ForegroundColor Gray
}
