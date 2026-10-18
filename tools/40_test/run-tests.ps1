# notes/samples の Zig サンプルを zig test で全件実行する
# zig の場所は環境変数 ZIG で差し替えられる（既定は C:/Tools/Zig/zig.exe）
$ErrorActionPreference = 'Stop'
$zigExe = if ($env:ZIG) { $env:ZIG } else { 'C:/Tools/Zig/zig.exe' }
$sampleDir = Join-Path $PSScriptRoot '../../notes/samples'
$sampleFiles = @(Get-ChildItem -LiteralPath $sampleDir -Filter '*.zig' | Sort-Object Name)
if ($sampleFiles.Count -eq 0) { Write-Host "テスト対象が見つかりません"; exit 1 }

$failCount = 0
foreach ($sampleFile in $sampleFiles) {
	Write-Host "== $($sampleFile.Name)"
	# zig test は結果を stderr に出す。5.1 で 2>&1 すると例外扱いで止まるため、リダイレクトしない
	& $zigExe test $sampleFile.FullName
	if ($LASTEXITCODE -ne 0) { $failCount++ }
}
if ($failCount -gt 0) { Write-Host "失敗: $failCount / $($sampleFiles.Count) ファイル"; exit 1 }
Write-Host "すべて成功: $($sampleFiles.Count) ファイル"
