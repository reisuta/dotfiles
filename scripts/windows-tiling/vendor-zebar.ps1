#Requires -Version 5.1
<#
.SYNOPSIS
    Zebar の JS モジュールとその依存を esm.sh から取得し、ウィジェットパックへ固める。

.DESCRIPTION
    bar.html が実行時に CDN を読まないようにするためのもの。
    CDN 直読みだと (1) バーの文脈で第三者のコードが動く経路になり、
    (2) 動的 import なので SRI が付けられず、(3) オフラインで描画されない。

    esm.sh の ?bundle / ?standalone / ?bundle-deps はいずれも依存をインライン化せず、
    /@tauri-apps/... と /luxon@... を絶対パスで参照したままになる。そのため
    参照を再帰的に辿って取得し、絶対パスを ./<平坦名> へ書き換えている。

    luxon はエントリポイントごとに全体が入った状態で配信されるため、
    取得後のサイズは 600KB 強になる (大半が luxon の重複)。

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\vendor-zebar.ps1
#>
[CmdletBinding()]
param(
    # 取得先。既定はこのスクリプトの隣のウィジェットパック。
    # $PSScriptRoot は param ブロックの既定値評価では空になるので本体で解決する。
    [string]$OutDir = '',

    # Zebar 本体のバージョンに合わせること (winget list glzr-io.zebar で確認)。
    [string]$Entry = '/zebar@3.3.1/es2022/zebar.bundle.mjs'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $OutDir) {
    $here = $PSScriptRoot
    if (-not $here) { $here = Split-Path $MyInvocation.MyCommand.Path -Parent }
    $OutDir = Join-Path $here 'zebar\tokyo-night\vendor'
}

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

# 消すのは取得物だけ。README.md と .gitignore は版管理下なので残す。
Get-ChildItem $OutDir -File |
    Where-Object { $_.Extension -eq '.mjs' -or $_.Name -eq 'SHA256SUMS' } |
    Remove-Item -Force

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

# import / export ... from "/..." の位置にある絶対パスだけを拾う。
# コード中のただの文字列を巻き込まないための限定。
$ws = '[' + '\s' + ']*'
$pattern = '((?:from|import)' + $ws + ')"(/[^"]+)"'

function ConvertTo-FlatName {
    param([Parameter(Mandatory)][string]$UrlPath)
    return ($UrlPath.TrimStart('/') -replace '/', '__')
}

$queue = New-Object System.Collections.Queue
$queue.Enqueue($Entry)
$seen = @{}
$count = 0

while ($queue.Count -gt 0) {
    $urlPath = [string]$queue.Dequeue()
    if ($seen.ContainsKey($urlPath)) { continue }
    $seen[$urlPath] = $true

    $wc = New-Object System.Net.WebClient
    $wc.Encoding = [System.Text.Encoding]::UTF8
    $body = $wc.DownloadString('https://esm.sh' + $urlPath)
    $wc.Dispose()

    # 空を黙って保存すると「外部参照が無い」ように見えてしまうので必ず落とす。
    if ([string]::IsNullOrWhiteSpace($body)) { throw "空のレスポンス: $urlPath" }

    $deps = @([regex]::Matches($body, $pattern) | ForEach-Object { $_.Groups[2].Value } | Sort-Object -Unique)

    $out = $body
    foreach ($dep in $deps) {
        $out = $out.Replace('"' + $dep + '"', '"./' + (ConvertTo-FlatName $dep) + '"')
        if (-not $seen.ContainsKey($dep)) { $queue.Enqueue($dep) }
    }

    $name = ConvertTo-FlatName $urlPath
    [System.IO.File]::WriteAllText((Join-Path $OutDir $name), $out, $utf8NoBom)
    $count++
    Write-Host ("  {0,3}. {1,-56} deps={2}" -f $count, $name, $deps.Count)
}

# bar.html から読む入口。実体のファイル名にバージョンが入るため、
# バージョンを上げてもここだけ直せば bar.html は触らずに済む。
$shim = "export * from './{0}';`n" -f (ConvertTo-FlatName $Entry)
[System.IO.File]::WriteAllText((Join-Path $OutDir 'zebar.mjs'), $shim, $utf8NoBom)

# 外部参照が残っていないことを確認する。ここが本スクリプトの目的なので必ず検査する。
# 対象は取得物 (*.mjs) だけ。README.md は説明のために URL を本文に含むので除く。
$leaked = @()
foreach ($f in Get-ChildItem $OutDir -File -Filter '*.mjs') {
    $t = [System.IO.File]::ReadAllText($f.FullName)
    foreach ($m in [regex]::Matches($t, '(?:from|import)[ ]*"([^"]+)"')) {
        if ($m.Groups[1].Value -notmatch '^\./') { $leaked += "$($f.Name) -> $($m.Groups[1].Value)" }
    }
    foreach ($m in [regex]::Matches($t, 'https?://[^"'' )]+')) {
        $leaked += "$($f.Name) -> $($m.Value)"
    }
}

Write-Host ''
if ($leaked) {
    Write-Host '外部参照が残っています:' -ForegroundColor Red
    $leaked | Sort-Object -Unique | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    throw '取得に失敗しました。'
}

# 取得物のハッシュ一覧を残す。これはリポジトリに入れて版管理し、
# setup-windows-tiling.ps1 が取得物の検証に使う。
# (.mjs 本体はライセンス上リポジトリに入れられないため、
#  「何を取ってくるべきか」だけを版管理する形にしている)
$sums = Get-ChildItem $OutDir -File -Filter '*.mjs' | Sort-Object Name | ForEach-Object {
    '{0}  {1}' -f (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLower(), $_.Name
}
[System.IO.File]::WriteAllText((Join-Path $OutDir 'SHA256SUMS'), (($sums -join "`n") + "`n"), $utf8NoBom)

$size = (Get-ChildItem $OutDir -File | Measure-Object Length -Sum).Sum / 1KB
Write-Host ("完了: {0} ファイル / {1:N0} KB / 外部参照なし" -f ($count + 1), $size) -ForegroundColor Green
Write-Host ("SHA256SUMS を更新しました ({0} 件)。差分が出たら取得元の変更を意味する。" -f $sums.Count) -ForegroundColor Gray
