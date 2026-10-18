param([string]$Database='bank_txn')
$ErrorActionPreference='Stop'
$root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$order=@(Get-Content "$root/build/file_order.txt" | Where-Object {$_ -notmatch '^#' -and $_.Trim()} | ForEach-Object {($_ -split '\|')[0].Trim()})
$fails=0
foreach ($build in @('run_all.sql','run_all_A_standalone.sql')) {
 $last=-1
 foreach ($line in Get-Content "$root/build/$build") {
  if ($line -match '^\s*SOURCE\s+([^;]+);?\s*$') {
   $path=$Matches[1].Trim()
   $index=[array]::IndexOf($order,$path)
   $ok=$index -gt $last -and (Test-Path (Join-Path $root $path))
   $status=if ($ok) {'PASS'} else {'FAIL'}
   Write-Output "TEST|$status|$build SOURCE $path|present and ordered in file_order.txt"
   if (!$ok) {$fails++}; $last=$index
  }
 }
}
if ($fails) {exit 1}
