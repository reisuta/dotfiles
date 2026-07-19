#Requires -Version 5.1
<#
.SYNOPSIS
    Windows のレジストリ設定を一括適用する。新しいマシンのセットアップ用。

.DESCRIPTION
    HKCU 部分は管理者不要・再起動不要 (explorer 再起動のみ)。
    HKLM 部分 (Capslock -> Ctrl、ロングパス有効化) は管理者権限が必要で、
    非管理者で実行した場合は自動的にスキップされる。

    すべて冪等。既に希望の値なら [skip] と表示して何もしない。

.EXAMPLE
    # 何が変わるか確認するだけ (一切書き込まない)
    powershell -ExecutionPolicy Bypass -File .\setup-windows-registry.ps1 -DryRun

.EXAMPLE
    # HKCU のみ適用 (通常の PowerShell)
    powershell -ExecutionPolicy Bypass -File .\setup-windows-registry.ps1

.EXAMPLE
    # HKLM も含めて全部適用 (管理者 PowerShell)
    powershell -ExecutionPolicy Bypass -File .\setup-windows-registry.ps1
#>
[CmdletBinding()]
param(
    # 書き込まずに差分だけ表示する
    [switch]$DryRun,

    # 適用後に explorer.exe を再起動しない
    [switch]$NoRestartExplorer
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Changed = 0
$script:Skipped = 0

# ------------------------------------------------------------
# ヘルパー
# ------------------------------------------------------------

function Format-Val {
    param($Value)
    if ($null -eq $Value) { return '(未設定)' }
    if ($Value -is [byte[]]) { return ($Value | ForEach-Object { $_.ToString('X2') }) -join ' ' }
    if ($Value -is [string] -and $Value -eq '') { return '(空文字列)' }
    return "$Value"
}

function Set-Reg {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)]$Value,
        [ValidateSet('DWord', 'String', 'Binary', 'ExpandString')][string]$Type = 'DWord',
        [string]$Note = ''
    )

    # 現在値の取得 (キー自体が無い場合も含めて $null に倒す)
    $current = $null
    if (Test-Path $Path) {
        $prop = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
        if ($null -ne $prop) { $current = $prop.$Name }
    }

    # 既に希望の値か判定
    $same = $false
    if ($null -ne $current) {
        if ($Type -eq 'Binary') {
            $same = -not (Compare-Object -ReferenceObject $current -DifferenceObject $Value -SyncWindow 0)
        }
        else {
            $same = ($current -eq $Value)
        }
    }

    if ($same) {
        Write-Host ("    [skip] {0}" -f $Name) -ForegroundColor DarkGray
        $script:Skipped++
        return
    }

    Write-Host ("    [set ] {0} : {1} -> {2}" -f $Name, (Format-Val $current), (Format-Val $Value)) -ForegroundColor Yellow
    if ($Note) { Write-Host ("           {0}" -f $Note) -ForegroundColor DarkGray }
    $script:Changed++

    if ($DryRun) { return }

    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
}

function Write-Section {
    param([string]$Title)
    Write-Host ''
    Write-Host "== $Title" -ForegroundColor Cyan
}

$isAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

Write-Host ''
Write-Host '--- Windows レジストリ設定 ---' -ForegroundColor Green
if ($DryRun) { Write-Host '  DryRun: 書き込みは行いません' -ForegroundColor Magenta }
Write-Host ("  管理者権限: {0}" -f $(if ($isAdmin) { 'あり' } else { 'なし (HKLM はスキップ)' }))

# ============================================================
# HKCU: 管理者不要
# ============================================================

$adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'

Write-Section 'エクスプローラー表示'
Set-Reg $adv 'Hidden'                1 -Note '隠しファイルを表示 (1=表示 / 2=非表示)'
Set-Reg $adv 'HideFileExt'           0 -Note '拡張子を表示'
Set-Reg $adv 'LaunchTo'              1 -Note '起動時に「PC」を開く (1=PC / 2=クイックアクセス)'
Set-Reg $adv 'NavPaneShowAllFolders' 1 -Note 'ナビゲーションウィンドウに全フォルダを表示'
Set-Reg $adv 'SeparateProcess'       1 -Note 'ウィンドウごとに別プロセス (1つ固まっても巻き込まれない)'

Write-Section 'タスクバー'
Set-Reg $adv 'TaskbarAl'                0 -Note 'アイコンを左寄せ (Windows 11 のみ)'
Set-Reg $adv 'ShowTaskViewButton'       0 -Note 'タスクビューボタンを隠す'
Set-Reg $adv 'TaskbarDa'                0 -Note 'ウィジェットを隠す'
Set-Reg $adv 'ShowSecondsInSystemClock' 1 -Note '時計に秒を表示'

Write-Section '右クリックメニューを Windows 10 形式に戻す'
# 既定値を「空文字列」にして存在させるのがポイント。キーを消すのでは効かない。
# 24H2 まで動作確認済みの非公式手段。将来 Microsoft に塞がれる可能性がある。
$clsid = 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32'
if (Test-Path $clsid) {
    Write-Host '    [skip] クラシックメニューは設定済み' -ForegroundColor DarkGray
    $script:Skipped++
}
else {
    Write-Host '    [set ] クラシックメニューを有効化' -ForegroundColor Yellow
    $script:Changed++
    if (-not $DryRun) { New-Item -Path $clsid -Force -Value '' | Out-Null }
}

Write-Section 'フォルダーの種類の自動判別を無効化'
# Windows がフォルダ内容を見て勝手に「画像」「音楽」レイアウトへ切り替えるのを止める。
# 詳細表示の「列」そのものはレジストリでの可搬化が困難なため、ここでは自動切替の抑止のみ。
$allFolders = 'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags\AllFolders\Shell'
Set-Reg $allFolders 'FolderType' 'NotSpecified' -Type String -Note '全フォルダで汎用レイアウトを使う'

Write-Section 'キーボード / マウスの応答'
Set-Reg 'HKCU:\Control Panel\Keyboard' 'KeyboardDelay'  '0'  -Type String -Note 'リピート開始を最短に'
Set-Reg 'HKCU:\Control Panel\Keyboard' 'KeyboardSpeed'  '31' -Type String -Note 'リピート速度を最速に'
Set-Reg 'HKCU:\Control Panel\Mouse'    'MouseSpeed'      '0' -Type String -Note 'マウス加速オフ'
Set-Reg 'HKCU:\Control Panel\Mouse'    'MouseThreshold1' '0' -Type String
Set-Reg 'HKCU:\Control Panel\Mouse'    'MouseThreshold2' '0' -Type String

Write-Section 'スタートメニューの Web 検索を無効化'
Set-Reg 'HKCU:\Software\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions' 1 `
    -Note 'Bing 検索候補を出さない'

# ============================================================
# HKLM: 要管理者
# ============================================================

Write-Section 'システム設定 (要管理者)'
if (-not $isAdmin) {
    Write-Host '    管理者権限が無いためスキップしました。' -ForegroundColor DarkYellow
    Write-Host '    Capslock->Ctrl とロングパス有効化を適用するには、' -ForegroundColor DarkYellow
    Write-Host '    管理者 PowerShell で再実行してください。' -ForegroundColor DarkYellow
}
else {
    # Capslock を左 Ctrl にリマップ。
    # 構造: ヘッダ8バイト(0) + エントリ数(2 = 1マッピング + 終端) + マッピング + 終端4バイト(0)
    # マッピングは [変換後スキャンコード][変換前スキャンコード] のリトルエンディアン。
    #   0x1D = 左Ctrl / 0x3A = Capslock
    # ドライバ層で効くのでログイン画面でも有効、常駐プロセス不要。反映には再起動が必要。
    $scancodeMap = [byte[]](
        0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00,
        0x02, 0x00, 0x00, 0x00,
        0x1D, 0x00, 0x3A, 0x00,
        0x00, 0x00, 0x00, 0x00
    )
    Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layout' 'Scancode Map' $scancodeMap `
        -Type Binary -Note 'Capslock -> 左Ctrl (反映には再起動が必要)'

    Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' 'LongPathsEnabled' 1 `
        -Note 'パス260文字制限を解除 (git / node_modules 対策)'
}

# ============================================================
# 仕上げ
# ============================================================

Write-Host ''
Write-Host ("変更: {0} 件 / 変更なし: {1} 件" -f $script:Changed, $script:Skipped) -ForegroundColor Green

if ($DryRun) {
    Write-Host 'DryRun のため何も書き込んでいません。' -ForegroundColor Magenta
    return
}

if ($script:Changed -eq 0) {
    Write-Host 'すべて適用済みでした。' -ForegroundColor Green
    return
}

if (-not $NoRestartExplorer) {
    Write-Host 'explorer.exe を再起動します...' -ForegroundColor Cyan
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) {
        Start-Process explorer.exe
    }
}

Write-Host ''
Write-Host '完了。以下は反映に追加操作が必要です:' -ForegroundColor Green
Write-Host '  - Capslock -> Ctrl        : 再起動' -ForegroundColor Gray
Write-Host '  - ロングパス有効化        : 再起動' -ForegroundColor Gray
Write-Host '  - キーリピート / マウス   : 再ログオン' -ForegroundColor Gray
