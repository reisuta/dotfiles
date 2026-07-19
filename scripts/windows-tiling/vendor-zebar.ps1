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
    [string]$Entry = '/zebar@3.3.1/es2022/zebar.bundle.mjs',

    # SHA256SUMS を取得物で作り直す。バージョンを上げるときだけ使う。
    #
    # 既定では SHA256SUMS は「信頼の基点」として読むだけで、書き換えない。
    # 取得のたびに上書きしてしまうと、改竄された配信物のハッシュが
    # そのまま次回の期待値になり、検証が意味を失うため。
    [switch]$UpdateHashes
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $OutDir) {
    $here = $PSScriptRoot
    if (-not $here) { $here = Split-Path $MyInvocation.MyCommand.Path -Parent }
    $OutDir = Join-Path $here 'zebar\tokyo-night\vendor'
}

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

$sumsPath = Join-Path $OutDir 'SHA256SUMS'

# 既存の期待ハッシュを先に読み込む。取得物で上書きする前に確保しておく。
$expected = @{}
if (Test-Path $sumsPath) {
    foreach ($line in (Get-Content $sumsPath)) {
        if ($line -match '^([0-9a-f]{64})\s+(.+)$') { $expected[$Matches[2]] = $Matches[1] }
    }
}

# 消すのは取得物だけ。README.md / .gitignore / SHA256SUMS は残す。
Get-ChildItem $OutDir -File -Filter '*.mjs' | Remove-Item -Force

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

# 取得物のハッシュを算出する。
$actual = @{}
foreach ($f in (Get-ChildItem $OutDir -File -Filter '*.mjs' | Sort-Object Name)) {
    $actual[$f.Name] = (Get-FileHash $f.FullName -Algorithm SHA256).Hash.ToLower()
}

if ($expected.Count -gt 0 -and -not $UpdateHashes) {
    # 既存の SHA256SUMS が信頼の基点。取得物をこれと突き合わせる。
    # 一致しなければ配信内容が変わったということなので、上書きせずに落とす。
    $diff = @()
    foreach ($name in ($expected.Keys | Sort-Object)) {
        if (-not $actual.ContainsKey($name)) { $diff += "$name : 取得できなかった" ; continue }
        if ($actual[$name] -ne $expected[$name]) { $diff += "$name : ハッシュ不一致" }
    }
    foreach ($name in ($actual.Keys | Sort-Object)) {
        if (-not $expected.ContainsKey($name)) { $diff += "$name : SHA256SUMS に無いファイル" }
    }

    Write-Host ''
    if ($diff) {
        Write-Host 'SHA256SUMS と一致しません:' -ForegroundColor Red
        $diff | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
        Write-Host ''
        Write-Host '取得元の配信内容が変わっています。中身を確認するまで受け入れないこと。' -ForegroundColor Red
        Write-Host '意図した更新 (バージョン変更など) なら -UpdateHashes を付けて再実行する。' -ForegroundColor Yellow
        throw 'ハッシュ検証に失敗しました。'
    }
    Write-Host ("検証OK: {0} ファイルが SHA256SUMS と一致 / 外部参照なし" -f $actual.Count) -ForegroundColor Green
}
else {
    # 初回、または -UpdateHashes を明示したとき。ここでだけ基点を書き換える。
    $sums = ($actual.Keys | Sort-Object | ForEach-Object { '{0}  {1}' -f $actual[$_], $_ })
    [System.IO.File]::WriteAllText($sumsPath, (($sums -join "`n") + "`n"), $utf8NoBom)
    Write-Host ''
    if ($UpdateHashes) {
        Write-Host ("SHA256SUMS を更新しました ({0} 件)。差分を必ずレビューしてからコミットすること。" -f $sums.Count) -ForegroundColor Yellow
    }
    else {
        Write-Host ("SHA256SUMS を新規作成しました ({0} 件)。" -f $sums.Count) -ForegroundColor Yellow
    }
}

$size = (Get-ChildItem $OutDir -File -Filter '*.mjs' | Measure-Object Length -Sum).Sum / 1KB
Write-Host ("取得: {0} ファイル / {1:N0} KB" -f $actual.Count, $size) -ForegroundColor Green
