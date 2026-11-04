param()
. "$PSScriptRoot/../lib/Common.ps1"
$rows=@(); $sources=@()
foreach ($n in @('04','05','06','07')) {
 $dir=Get-ChildItem "evidence/raw/EXP-$n" -Directory | Where-Object { Test-Path "$($_.FullName)/results.txt" } | Sort-Object Name -Descending | Select-Object -First 1
 if (!$dir) { throw "No completed measured EXP-$n run." }
 $sources+=$dir.FullName
 $rows+=Get-Content "$($dir.FullName)/results.txt" | Where-Object { $_ -match '^RESULT\|' }
}
$text="# Measured isolation matrix`n`nSources:`n"+($sources -join "`n")+"`n`n| Isolation | Lost update: textbook expectation | Measured | Dirty: textbook expectation | Measured | Nonrepeatable: textbook expectation | Measured | Phantom: textbook expectation | Measured | Difference / implementation detail |`n|---|---|---|---|---|---|---|---|---|---|`n"
foreach ($level in @('READ UNCOMMITTED','READ COMMITTED','REPEATABLE READ','SERIALIZABLE')) {
 $expected=switch ($level) {
 'READ UNCOMMITTED' { @('OBSERVED','OBSERVED','OBSERVED','OBSERVED') }
 'READ COMMITTED' { @('OBSERVED','NOT OBSERVED','OBSERVED','OBSERVED') }
 'REPEATABLE READ' { @('OBSERVED','NOT OBSERVED','NOT OBSERVED','PERMITTED') }
 'SERIALIZABLE' { @('NOT OBSERVED','NOT OBSERVED','NOT OBSERVED','NOT OBSERVED') }
 }
 $v=@(); $diff=@()
 for ($i=0;$i -lt 4;$i++) {
  $n=@('04','05','06','07')[$i]; $key=if ($n -eq '04') { 'naive' } else { 'anomaly' }
  $r=@($rows | Where-Object { $_.StartsWith("RESULT|EXP-$n|$level|$key|") })
  if ($r.Count -ne 1) { throw "Missing/duplicate cell $level $n" }
  $m=($r[0] -split '\|')[4]; $v+=@($expected[$i],$m)
  if ($m.Replace(' (nuance)','') -ne $expected[$i]) { $diff+=$n }
 }
 $text+="| $level | "+($v -join ' | ')+" | "+$(if ($diff.Count) { $diff -join ',' } else { 'None' })+" |`n"
}
$text+="`nTextbook OBSERVED means the anomaly is permitted and the schedule is designed to expose it, not that every execution must exhibit it. PERMITTED for RR phantoms is the ANSI minimum guarantee: InnoDB plain consistent reads provide a stable snapshot, hence the flagged stronger result. SERIALIZABLE BLOCKED also prevents the anomaly; its flagged difference describes the protection mechanism, not a violation. Locking reads use the current committed version. Lost-update expectations concern the deliberately unsafe read/absolute-write procedure, not an additional ANSI isolation prohibition.`n"
Save-Text evidence/EV-EXP08-matrix.md $text
Write-Output $text
