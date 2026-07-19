#Requires -Version 5.1
<#
.SYNOPSIS
    Windows にタイリング環境 (GlazeWM + Zebar + Flow Launcher) を導入・配置する。

.DESCRIPTION
    Arch の Sway 環境を Windows 側で再現するための一式。
    キーバインドは dot_config/sway/config に合わせてある (modifier のみ alt)。

    構成:
      GlazeWM      タイリング WM        <- sway
      Zebar        ステータスバー        <- waybar
      Flow Launcher ランチャー           <- rofi
      Files        ファイラ              <- yazi

    管理者権限は不要。winget のパッケージ導入時のみ UAC が出ることがある。
    すべて冪等。既に希望の状態なら [skip] と表示して何もしない。

.EXAMPLE
    # 何が変わるか確認するだけ (一切書き込まない)
    powershell -ExecutionPolicy Bypass -File .\setup-windows-tiling.ps1 -DryRun

.EXAMPLE
    # 配置のみ (winget を叩かない。導入済みマシンでの設定更新用)
    powershell -ExecutionPolicy Bypass -File .\setup-windows-tiling.ps1 -SkipInstall

.EXAMPLE
    # 全部
    powershell -ExecutionPolicy Bypass -File .\setup-windows-tiling.ps1
#>
[CmdletBinding()]
param(
    # 書き込まずに差分だけ表示する
    [switch]$DryRun,

    # winget によるパッケージ導入を飛ばす
    [switch]$SkipInstall,

    # 壁紙の生成と適用を飛ばす
    [switch]$SkipWallpaper
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Changed = 0
$script:Skipped = 0
$script:Failed  = 0

$PayloadDir = Join-Path $PSScriptRoot 'windows-tiling'
if (-not (Test-Path $PayloadDir)) {
    throw "配置元が見つかりません: $PayloadDir"
}

# winget パッケージ。ここが唯一の正。
# Microsoft.DotNet.DesktopRuntime.10 は Files の依存。
#   これが無いと Files は「無言で起動失敗し、ブラウザでダウンロードページを開くだけ」
#   になり、原因が分かりにくい。
$Packages = @(
    'glzr-io.glazewm'
    'Flow-Launcher.Flow-Launcher'
    'FilesCommunity.Files'
    'DEVCOM.JetBrainsMonoNerdFont'
    'Microsoft.DotNet.DesktopRuntime.10'
)

# ------------------------------------------------------------
# ヘルパー
# ------------------------------------------------------------

function Write-Section {
    param([string]$Title)
    Write-Host ''
    Write-Host "== $Title" -ForegroundColor Cyan
}

function Write-Set {
    param([string]$Message, [string]$Note = '')
    Write-Host ("    [set ] {0}" -f $Message) -ForegroundColor Yellow
    if ($Note) { Write-Host ("           {0}" -f $Note) -ForegroundColor DarkGray }
    $script:Changed++
}

function Write-Skip {
    param([string]$Message)
    Write-Host ("    [skip] {0}" -f $Message) -ForegroundColor DarkGray
    $script:Skipped++
}

function Write-Fail {
    param([string]$Message)
    Write-Host ("           失敗: {0}" -f $Message) -ForegroundColor Red
    $script:Changed--
    $script:Failed++
}

# 内容が同じなら何もしないファイル配置。
function Copy-Payload {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Dest,
        [string]$Label = ''
    )

    if (-not $Label) { $Label = Split-Path $Dest -Leaf }

    # ハッシュ取得に失敗しても「差分あり」に倒してコピーへ進む。
    # $ErrorActionPreference = 'Stop' のため、ここを裸で呼ぶと
    # ネットワーク越し ($PSScriptRoot が \\wsl.localhost の場合など) の
    # 一時的な読み取り失敗でスクリプト全体が落ちる。
    if (Test-Path $Dest) {
        try {
            $a = (Get-FileHash $Source -Algorithm SHA256).Hash
            $b = (Get-FileHash $Dest   -Algorithm SHA256).Hash
            if ($a -eq $b) { Write-Skip $Label; return }
        }
        catch {
            Write-Host ("           ハッシュ比較に失敗 ({0})。コピーし直します。" -f $_.Exception.Message) -ForegroundColor DarkYellow
        }
    }

    Write-Set $Label $Dest
    if ($DryRun) { return }

    try {
        $parent = Split-Path $Dest -Parent
        if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        Copy-Item $Source $Dest -Force
    }
    catch { Write-Fail $_.Exception.Message }
}

function Test-WingetPackage {
    param([Parameter(Mandatory)][string]$Id)
    # `winget list --id` は未導入時に非ゼロで終了する。出力は見ずに終了コードで判定する。
    $null = winget list --id $Id --exact --disable-interactivity 2>$null
    return ($LASTEXITCODE -eq 0)
}

# ------------------------------------------------------------

Write-Host ''
Write-Host '--- Windows タイリング環境 ---' -ForegroundColor Green
if ($DryRun) { Write-Host '  DryRun: 書き込みは行いません' -ForegroundColor Magenta }

# ============================================================
# 1. パッケージ導入
# ============================================================

Write-Section 'パッケージ (winget)'
if ($SkipInstall) {
    Write-Host '    -SkipInstall のため飛ばしました。' -ForegroundColor DarkYellow
}
elseif (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host '    winget が見つかりません。App Installer を導入してください。' -ForegroundColor Red
    $script:Failed++
}
else {
    foreach ($id in $Packages) {
        if (Test-WingetPackage $id) { Write-Skip $id; continue }

        Write-Set $id '導入中...'
        if ($DryRun) { continue }

        $null = winget install --id $id --exact `
            --accept-package-agreements --accept-source-agreements `
            --disable-interactivity --silent 2>&1
        if ($LASTEXITCODE -ne 0) { Write-Fail "winget 終了コード $LASTEXITCODE" }
    }
}

# ============================================================
# 2. 設定ファイルの配置
# ============================================================

Write-Section 'GlazeWM'
Copy-Payload (Join-Path $PayloadDir 'glazewm\config.yaml') `
             (Join-Path $env:USERPROFILE '.glzr\glazewm\config.yaml') `
             'config.yaml'

Write-Section 'Zebar (自作パック tokyo-night)'
# Zebar のローカルパックは「ディレクトリ名がそのまま pack ID」。
# settings.json に local.tokyo-night と書くと "No widget pack found" になる。
foreach ($f in @('zpack.json', 'bar.html', 'styles.css')) {
    Copy-Payload (Join-Path $PayloadDir "zebar\tokyo-night\$f") `
                 (Join-Path $env:USERPROFILE ".glzr\zebar\tokyo-night\$f") `
                 "tokyo-night/$f"
}

# vendor/ は bar.html が読む zebar モジュール一式。ここが欠けるとバーが空になる。
#
# .mjs 本体はリポジトリに入れていない。zebar は GPL-3.0-only、luxon は MIT、
# @tauri-apps/api は Apache-2.0 OR MIT で、いずれも再配布には著作権表示の保持が要るが、
# esm.sh が配信するミニファイ版はその表示を削ぎ落としている。条件を満たせないので
# 再配布せず、「取得スクリプト + 期待ハッシュ」だけを版管理して各自の環境で取得する。
$vendorSrc  = Join-Path $PayloadDir 'zebar\tokyo-night\vendor'
$vendorDest = Join-Path $env:USERPROFILE '.glzr\zebar\tokyo-night\vendor'
$sumsFile   = Join-Path $vendorSrc 'SHA256SUMS'

if (-not (Test-Path $sumsFile)) {
    Write-Host '    SHA256SUMS がありません。vendor-zebar.ps1 を先に実行してください。' -ForegroundColor Red
    $script:Failed++
}
else {
    # 期待ハッシュを読む (形式: "<sha256>  <ファイル名>")
    $expected = @{}
    foreach ($line in (Get-Content $sumsFile)) {
        if ($line -match '^([0-9a-f]{64})\s+(.+)$') { $expected[$Matches[2]] = $Matches[1] }
    }

    # 取得済みか、内容が期待どおりかを確認する
    $needFetch = $false
    foreach ($name in $expected.Keys) {
        $src = Join-Path $vendorSrc $name
        if (-not (Test-Path $src)) { $needFetch = $true; break }
        if ((Get-FileHash $src -Algorithm SHA256).Hash.ToLower() -ne $expected[$name]) { $needFetch = $true; break }
    }

    if ($needFetch) {
        Write-Set 'vendor/*.mjs' 'esm.sh から取得します (リポジトリには含めていない)'
        if (-not $DryRun) {
            try { & (Join-Path $PayloadDir 'vendor-zebar.ps1') -OutDir $vendorSrc | Out-Null }
            catch { Write-Fail $_.Exception.Message }
        }
    }

    # 取得物を検証してから配置する。ここを飛ばすと固定した意味が無くなる。
    if (-not $DryRun) {
        $bad = @()
        foreach ($name in $expected.Keys) {
            $src = Join-Path $vendorSrc $name
            if (-not (Test-Path $src)) { $bad += "$name (取得できていない)"; continue }
            $actual = (Get-FileHash $src -Algorithm SHA256).Hash.ToLower()
            if ($actual -ne $expected[$name]) { $bad += "$name (ハッシュ不一致)" }
        }
        if ($bad) {
            Write-Host '    取得物が SHA256SUMS と一致しません:' -ForegroundColor Red
            $bad | ForEach-Object { Write-Host "      $_" -ForegroundColor Red }
            Write-Host '    取得元が変わった可能性があります。差分を確認するまで配置しません。' -ForegroundColor Red
            $script:Failed++
        }
        else {
            foreach ($name in ($expected.Keys | Sort-Object)) {
                Copy-Payload (Join-Path $vendorSrc $name) (Join-Path $vendorDest $name) "vendor/$name"
            }
        }
    }
}

$zebarSettings = Join-Path $env:USERPROFILE '.glzr\zebar\settings.json'
$zebarWanted = @'
{
  "$schema": "https://github.com/glzr-io/zebar/raw/v3.3.1/resources/settings-schema.json",
  "startupConfigs": [
    {
      "pack": "tokyo-night",
      "widget": "bar",
      "preset": "default"
    }
  ]
}
'@
if ((Test-Path $zebarSettings) -and ((Get-Content $zebarSettings -Raw).Trim() -eq $zebarWanted.Trim())) {
    Write-Skip 'settings.json'
}
else {
    Write-Set 'settings.json' '起動するウィジェットを tokyo-night/bar に切替'
    if (-not $DryRun) {
        try {
            $parent = Split-Path $zebarSettings -Parent
            if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
            [System.IO.File]::WriteAllText($zebarSettings, $zebarWanted, (New-Object System.Text.UTF8Encoding($false)))
        }
        catch { Write-Fail $_.Exception.Message }
    }
}

Write-Section 'Flow Launcher'
Copy-Payload (Join-Path $PayloadDir 'flow-launcher\Tokyo Night.xaml') `
             (Join-Path $env:APPDATA 'FlowLauncher\Themes\Tokyo Night.xaml') `
             'Tokyo Night.xaml'

# Flow Launcher は終了時に Settings.json を書き戻すため、起動中に編集しても捨てられる。
# 必ず止めてから触る。
$flowSettings = Join-Path $env:APPDATA 'FlowLauncher\Settings\Settings.json'
if (-not (Test-Path $flowSettings)) {
    Write-Host '    Settings.json がまだありません。Flow Launcher を一度起動してから再実行してください。' -ForegroundColor DarkYellow
}
else {
    $flow = Get-Content $flowSettings -Raw | ConvertFrom-Json
    # Sway は $mod+d が rofi。alt+space は GlazeWM の wm-cycle-focus に使うため空ける。
    if ($flow.Theme -eq 'Tokyo Night' -and $flow.Hotkey -eq 'Alt + D') {
        Write-Skip 'Settings.json (Theme / Hotkey)'
    }
    else {
        Write-Set 'Settings.json' 'Theme=Tokyo Night / Hotkey=Alt + D'
        if (-not $DryRun) {
            try {
                $running = Get-Process 'Flow.Launcher' -ErrorAction SilentlyContinue
                if ($running) { $running | Stop-Process -Force; Start-Sleep -Seconds 3 }

                $t = [System.IO.File]::ReadAllText($flowSettings)
                $t = $t -replace '"Theme"\s*:\s*"[^"]*"',       '"Theme": "Tokyo Night"'
                $t = $t -replace '"ColorScheme"\s*:\s*"[^"]*"', '"ColorScheme": "Dark"'
                $t = $t -replace '"Hotkey"\s*:\s*"[^"]*"',      '"Hotkey": "Alt + D"'
                [System.IO.File]::WriteAllText($flowSettings, $t, (New-Object System.Text.UTF8Encoding($false)))

                if ($running) { Start-Process (Join-Path $env:LOCALAPPDATA 'FlowLauncher\Flow.Launcher.exe') }
            }
            catch { Write-Fail $_.Exception.Message }
        }
    }
}

# ============================================================
# 3. Windows Terminal の配色
# ============================================================

Write-Section 'Windows Terminal'
$wtCandidates = @(
    (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json')
    (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json')
)
$wt = $wtCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $wt) {
    Write-Host '    settings.json が見つかりません。一度 Windows Terminal を起動してください。' -ForegroundColor DarkYellow
}
else {
    $json = Get-Content $wt -Raw | ConvertFrom-Json
    $hasScheme = @($json.schemes | Where-Object { $_.name -eq 'Tokyo Night' }).Count -gt 0
    $hasDefault = $false
    if ($json.profiles.PSObject.Properties.Name -contains 'defaults') {
        $d = $json.profiles.defaults
        $hasDefault = ($d.PSObject.Properties.Name -contains 'colorScheme') -and ($d.colorScheme -eq 'Tokyo Night')
    }

    if ($hasScheme -and $hasDefault) {
        Write-Skip 'Tokyo Night スキーム / defaults'
    }
    else {
        Write-Set 'Tokyo Night スキームと defaults を追加' "$wt"
        if (-not $DryRun) {
            try {
                Copy-Item $wt "$wt.bak" -Force

                if (-not $hasScheme) {
                    $scheme = [ordered]@{
                        name                = 'Tokyo Night'
                        background          = '#1A1B26'; foreground   = '#C0CAF5'
                        black               = '#15161E'; brightBlack  = '#414868'
                        red                 = '#F7768E'; brightRed    = '#F7768E'
                        green               = '#9ECE6A'; brightGreen  = '#9ECE6A'
                        yellow              = '#E0AF68'; brightYellow = '#E0AF68'
                        blue                = '#7AA2F7'; brightBlue   = '#7AA2F7'
                        purple              = '#BB9AF7'; brightPurple = '#BB9AF7'
                        cyan                = '#7DCFFF'; brightCyan   = '#7DCFFF'
                        white               = '#A9B1D6'; brightWhite  = '#C0CAF5'
                        cursorColor         = '#C0CAF5'
                        selectionBackground = '#33467C'
                    }
                    $json.schemes = @($json.schemes) + [pscustomobject]$scheme
                }

                $defaults = [ordered]@{
                    antialiasingMode = 'grayscale'
                    colorScheme      = 'Tokyo Night'
                    cursorShape      = 'filledBox'
                    font             = [pscustomobject]@{ face = 'JetBrainsMono Nerd Font'; size = 10 }
                    opacity          = 92
                    padding          = '10'
                    scrollbarState   = 'hidden'
                    useAcrylic       = $true
                }
                $json.profiles.defaults = [pscustomobject]$defaults
                $json | Add-Member -NotePropertyName 'theme' -NotePropertyValue 'dark' -Force

                # 注意: ConvertTo-Json はコメントを落とす。settings.json に手書きコメントが
                # あるなら .bak から拾い直すこと。
                $json | ConvertTo-Json -Depth 100 |
                    Set-Content $wt -Encoding UTF8
            }
            catch { Write-Fail $_.Exception.Message }
        }
    }
}

# ============================================================
# 4. 壁紙
# ============================================================

if (-not $SkipWallpaper) {
    Write-Section '壁紙'
    $wallpaper = Join-Path $env:USERPROFILE 'Pictures\Wallpapers\tokyo-night.png'
    if (Test-Path $wallpaper) {
        Write-Skip 'tokyo-night.png (生成済み)'
    }
    else {
        Write-Set 'tokyo-night.png を生成' $wallpaper
        if (-not $DryRun) {
            try { & (Join-Path $PayloadDir 'make-wallpaper.ps1') | Out-Null }
            catch { Write-Fail $_.Exception.Message }
        }
    }

    if (-not $DryRun -and (Test-Path $wallpaper)) {
        Set-ItemProperty 'HKCU:\Control Panel\Desktop' -Name 'WallpaperStyle' -Value '10'  # 10 = Fill
        Set-ItemProperty 'HKCU:\Control Panel\Desktop' -Name 'TileWallpaper'  -Value '0'
        if (-not ('Wall' -as [type])) {
            Add-Type @'
using System.Runtime.InteropServices;
public class Wall {
    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
'@
        }
        # SPI_SETDESKWALLPAPER = 20 / SPIF_UPDATEINIFILE|SPIF_SENDWININICHANGE = 3
        [Wall]::SystemParametersInfo(20, 0, $wallpaper, 3) | Out-Null
    }
}

# ============================================================
# 5. タスクバーを自動的に隠す (Zebar をバーとして使うため)
# ============================================================

Write-Section 'タスクバー'
# StuckRects3 の byte[8] bit0 を立てる方法は explorer が起動・終了時に自分の状態を
# 書き戻すため潰される。Shell の API を直接叩くのが確実。
if (-not ('AppBarState' -as [type])) {
    Add-Type @'
using System;
using System.Runtime.InteropServices;
public class AppBarState {
    [StructLayout(LayoutKind.Sequential)]
    public struct APPBARDATA {
        public int cbSize; public IntPtr hWnd; public int uCallbackMessage;
        public int uEdge; public int left; public int top; public int right; public int bottom;
        public IntPtr lParam;
    }
    [DllImport("shell32.dll", SetLastError = true)]
    public static extern IntPtr SHAppBarMessage(int dwMessage, ref APPBARDATA pData);
    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr FindWindow(string cls, string win);
}
'@
}
$abd = New-Object AppBarState+APPBARDATA
$abd.cbSize = [System.Runtime.InteropServices.Marshal]::SizeOf($abd)
$state = [int][AppBarState]::SHAppBarMessage(0x00000004, [ref]$abd)   # ABM_GETSTATE

# 戻り値はビットフラグ。ABS_AUTOHIDE = 0x01 / ABS_ALWAYSONTOP = 0x02。
# 「自動的に隠す」かつ「常に手前に表示」なら 3 が返るので、等値比較では判定できない。
if (($state -band 0x01) -eq 0x01) {
    Write-Skip '自動的に隠す (設定済み)'
}
else {
    Write-Set '自動的に隠す'
    if (-not $DryRun) {
        $set = New-Object AppBarState+APPBARDATA
        $set.cbSize = [System.Runtime.InteropServices.Marshal]::SizeOf($set)
        $set.hWnd   = [AppBarState]::FindWindow('Shell_TrayWnd', $null)
        # ABM_SETSTATE は渡した値でフラグを丸ごと置き換えるので、
        # 現在値に ABS_AUTOHIDE を足す形にして他のフラグを落とさないようにする。
        # なお Windows 11 の実機では ABS_ALWAYSONTOP は取得も設定もできなかった
        # (3 を渡しても ABM_GETSTATE は 1 のまま)。このフラグは事実上死んでいるが、
        # 仕様どおりに書いておく分には害が無いので現在値を尊重する形にしてある。
        $set.lParam = [IntPtr]($state -bor 0x01)
        [AppBarState]::SHAppBarMessage(0x0000000A, [ref]$set) | Out-Null   # ABM_SETSTATE
    }
}

# ============================================================
# 6. 自動起動
# ============================================================

Write-Section '自動起動'
$glazePath = 'C:\Program Files\glzr.io\GlazeWM\glazewm.exe'
$lnkPath = Join-Path ([Environment]::GetFolderPath('Startup')) 'GlazeWM.lnk'

if (Test-Path $lnkPath) {
    Write-Skip 'GlazeWM.lnk'
}
elseif (-not (Test-Path $glazePath)) {
    Write-Host '    GlazeWM が未導入のためショートカットを作りませんでした。' -ForegroundColor DarkYellow
}
else {
    Write-Set 'GlazeWM.lnk' 'Zebar は GlazeWM の startup_commands から起動する'
    if (-not $DryRun) {
        try {
            $ws = New-Object -ComObject WScript.Shell
            $lnk = $ws.CreateShortcut($lnkPath)
            $lnk.TargetPath       = $glazePath
            $lnk.Arguments        = 'start'
            $lnk.WorkingDirectory = Split-Path $glazePath -Parent
            $lnk.Description      = 'GlazeWM tiling window manager'
            $lnk.Save()
        }
        catch { Write-Fail $_.Exception.Message }
    }
}

# ============================================================
# 仕上げ
# ============================================================

Write-Host ''
Write-Host ("変更: {0} 件 / 変更なし: {1} 件 / 失敗: {2} 件" -f $script:Changed, $script:Skipped, $script:Failed) -ForegroundColor Green

if ($DryRun) {
    Write-Host 'DryRun のため何も書き込んでいません。' -ForegroundColor Magenta
    return
}

# GlazeWM が動いていれば設定を読み直させる (再起動不要)。
$cli = 'C:\Program Files\glzr.io\GlazeWM\cli\glazewm.exe'
if ((Get-Process glazewm -ErrorAction SilentlyContinue) -and (Test-Path $cli)) {
    Write-Host 'GlazeWM の設定を再読み込みします...' -ForegroundColor Cyan
    & $cli command wm-reload-config | Out-Null
}

Write-Host ''
Write-Host '完了。以下は反映に追加操作が必要です:' -ForegroundColor Green
Write-Host '  - GlazeWM が未起動      : スタートメニューから起動 (次回ログオン以降は自動)' -ForegroundColor Gray
Write-Host '  - Zebar のバーが出ない  : GlazeWM を再起動 (alt+shift+e で終了)' -ForegroundColor Gray
Write-Host '  - Windows Terminal      : 開いているウィンドウは自動で再読み込みされる' -ForegroundColor Gray
