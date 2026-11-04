param([string]$Database='bank_txn',[string]$ScratchDatabase='bank_txn_scratch',
 [string]$IsolatedPrefix,[switch]$SkipQuick,[switch]$VerifyOptimized)
. "$PSScriptRoot/../build/mysql_common.ps1"
$root=Split-Path $PSScriptRoot -Parent
Set-Location $root
$stamp=(Get-Date -Format 'yyyyMMdd-HHmmss-fff')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8)
$dir=Join-Path $root "evidence/regression/$stamp"
[void][IO.Directory]::CreateDirectory($dir)
$rows=[Collections.Generic.List[object]]::new()
$environment=@{};foreach($key in @('BANK_TEST_BUILD_MODE','BANK_TEST_ISOLATED_PREFIX','BANK_TEST_OWNER_TOKEN','BANK_TEST_EVIDENCE_DIR')){$environment[$key]=[Environment]::GetEnvironmentVariable($key)}
$owned=[Collections.Generic.List[string]]::new()
function Report-Regression($Name,$Status,$Detail,$Evidence='') {
 $script:rows.Add([pscustomobject]@{Name=$Name;Status=$Status;Detail=($Detail -replace '\|','/');Evidence=$Evidence})
 Write-Output "CHECK|$Status|$Name|$Detail"
}
function Invoke-RegressionChild([string]$File,[string[]]$Arguments,[string]$Name) {
 $ErrorActionPreference='Continue'
 $out=@(& powershell -NoProfile -File $File @Arguments 2>&1 | ForEach-Object {"$_"});$code=$LASTEXITCODE
 $ErrorActionPreference='Stop'
 $path=Join-Path $script:dir "$Name.txt"
 $out | Set-Content $path -Encoding UTF8
 $summary=@($out | Where-Object {$_ -match '^TOTAL\|'} | Select-Object -Last 1)
 if(!$summary.Count){$summary=@("PASS=$(@($out -like 'TEST|PASS|*').Count); FAIL=$(@($out -like 'TEST|FAIL|*').Count)")}
 return [pscustomobject]@{Code=$code;Summary=($summary -join '');Output=$out;Evidence=$path}
}
function Check-Invariants([string]$Db,[string]$Name) {
 $out=@(Invoke-BankMysql -Database $Db -Sql 'SOURCE tests/integration/04_after_experiments.sql;')
 $path=Join-Path $script:dir "$Name.txt";$out | Set-Content $path -Encoding UTF8
 $ok=@($out -like 'TEST|PASS|*').Count -eq 6 -and !@($out -like 'TEST|FAIL|*').Count
 Report-Regression $Name $(if($ok){'PASS'}else{'FAIL'}) 'I1,I1b,I2,I3,I4,I5; six PASS required' $path
}
try {
 $env:BANK_TEST_EVIDENCE_DIR=$dir
 if($IsolatedPrefix) {
  if($IsolatedPrefix -cnotmatch '^bank_a_ci_[a-z0-9_]{1,32}$'){throw 'Invalid isolated prefix.'}
  $env:BANK_TEST_ISOLATED_PREFIX=$IsolatedPrefix
  $env:BANK_TEST_OWNER_TOKEN=[guid]::NewGuid().ToString('N')
  $env:BANK_TEST_EVIDENCE_DIR=$dir
  $Database=$IsolatedPrefix+'_main';$ScratchDatabase=$IsolatedPrefix+'_scratch'
  Assert-BankIsolatedContext
  # Preflight ALL names before creating anything; never adopt an existing database.
  $names=@($Database,$ScratchDatabase,($IsolatedPrefix+'_lab'))
  foreach($db in $names){Assert-BankDatabase $db;$n=@(Invoke-BankMysql -Sql "SELECT COUNT(*) FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='$db';")[0];if($n -ne '0'){throw "Isolated database already exists: $db"}}
  foreach($db in $names){Invoke-BankMysql -Sql "CREATE DATABASE $db CHARACTER SET utf8mb4;" | Out-Null;$owned.Add($db);Invoke-BankMysql -Database $db -Sql "CREATE TABLE _a_test_owner(owner_token CHAR(32) NOT NULL); INSERT INTO _a_test_owner VALUES('$env:BANK_TEST_OWNER_TOKEN');" | Out-Null}
 } else {Assert-BankDatabase $Database;Assert-BankDatabase $ScratchDatabase}
 if($Database -eq $ScratchDatabase){throw 'Development and scratch targets must differ.'}
 $b=@(Get-ChildItem schema/01_tables -File | Where-Object Name -Match '^(10|11|12|13|14|15|16)_.*\.sql$')
 $modes=@('Standalone');if($b.Count -eq 7){$modes+='Integrated'}else{Report-Regression 'Integrated build' 'MISSING' 'Seven real B tables unavailable'}
 foreach($mode in $modes) {
  $env:BANK_TEST_BUILD_MODE=$mode
  $r=Invoke-RegressionChild build/rebuild.ps1 @('-Database',$Database,'-Mode',$mode,'-IndexProfile','Baseline','-WithSeed') "$mode-build"
  Report-Regression "$mode rebuild" $(if($r.Code){'FAIL'}else{'PASS'}) $r.Summary $r.Evidence
  if($r.Code){continue}
  $snapshot=Get-BankEvidencePath 'evidence/EV-B0-1.txt'
  Copy-Item $snapshot "$dir/$mode-B0.txt"
  $r=Invoke-RegressionChild tests/run_tests.ps1 @('-Database',$Database,'-Mode',$mode,'-NoRebuild') "$mode-suite"
  Report-Regression "$mode full suite" $(if($r.Code){'FAIL'}else{'PASS'}) $r.Summary $r.Evidence
  Check-Invariants $Database "$mode-invariants"
  $r=Invoke-RegressionChild build/release_strip_lab_hook.ps1 @() "$mode-release-generation"
  Report-Regression "$mode release generation" $(if($r.Code){'FAIL'}else{'PASS'}) $r.Summary $r.Evidence
  $r=Invoke-RegressionChild tests/p6_static.ps1 @('-Database',$Database,'-Snapshot',"$dir/$mode-B0.txt") "$mode-static"
  Report-Regression "$mode static and B0" $(if($r.Code){'FAIL'}else{'PASS'}) $r.Summary $r.Evidence
 }
 $selected=if($modes -contains 'Integrated'){'Integrated'}else{'Standalone'}
 $env:BANK_TEST_BUILD_MODE=$selected
 $r=Invoke-RegressionChild tests/runtime_acceptance.ps1 @('-Database',$Database,'-Mode',$selected) 'runtime-acceptance'
 foreach($line in $r.Output | Where-Object {$_ -like 'ACCEPTANCE|*'}) {
  $v=$line -split '\|',4;Report-Regression $v[2] $v[1] $v[3] $r.Evidence
 }
 if($r.Code -notin @(0,2)){Report-Regression 'Runtime acceptance execution' 'FAIL' $r.Summary $r.Evidence}
 if(!$SkipQuick) {
  $r=Invoke-RegressionChild experiments/run_all_auto.ps1 @('-Database',$Database,'-Quick') 'experiments-quick'
  Report-Regression 'Bounded Quick smoke' $(if($r.Code){'FAIL'}else{'PASS'}) $r.Summary $r.Evidence
  Check-Invariants $Database 'post-Quick-invariants'
 } else {Report-Regression 'Bounded Quick smoke' 'NOT_RUN' 'Explicit -SkipQuick; not a passing experiment claim'}
 $r=Invoke-RegressionChild tests/run_release.ps1 @('-Database',$ScratchDatabase,'-Mode',$selected) 'release-suite'
 Report-Regression 'Release procedure suite' $(if($r.Code){'FAIL'}else{'PASS'}) $r.Summary $r.Evidence
 Check-Invariants $ScratchDatabase 'release-final-invariants'
 Check-Invariants $Database 'development-final-invariants'
 if($VerifyOptimized -and $selected -eq 'Integrated') {
  $r=Invoke-RegressionChild build/rebuild.ps1 @('-Database',$ScratchDatabase,'-Mode','Integrated','-IndexProfile','Optimized','-WithSeed') 'optimized-build'
  Report-Regression 'Explicit Optimized rebuild' $(if($r.Code){'FAIL'}else{'PASS'}) $r.Summary $r.Evidence
  if(!$r.Code) {
   $indexes=@(Invoke-BankMysql -Database $ScratchDatabase -Sql "SELECT DISTINCT INDEX_NAME FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND INDEX_NAME LIKE 'idx\\_%' ORDER BY INDEX_NAME;")
   $indexes | Set-Content "$dir/optimized-indexes.txt" -Encoding UTF8
   Report-Regression 'Explicit B optimized indexes' $(if($indexes.Count -eq 7){'PASS'}else{'FAIL'}) "$($indexes.Count) named B indexes; no benchmark executed" "$dir/optimized-indexes.txt"
   Check-Invariants $ScratchDatabase 'optimized-invariants'
  }
 }
} catch {Report-Regression 'Regression orchestration' 'FAIL' $_.Exception.Message}
finally {
 foreach($db in $owned) {
  try {
   Assert-BankDatabase $db
   $owner=@(Invoke-BankMysql -Database $db -Sql 'SELECT owner_token FROM _a_test_owner;')[0]
   if($owner -cne $env:BANK_TEST_OWNER_TOKEN){throw 'Owner marker mismatch; database retained.'}
   Invoke-BankMysql -Sql "DROP DATABASE $db;" | Out-Null
   Report-Regression "Cleanup $db" 'PASS' 'Only fresh run-owned isolated database removed'
  } catch {Report-Regression "Cleanup $db" 'FAIL' $_.Exception.Message}
 }
 foreach($key in $environment.Keys){[Environment]::SetEnvironmentVariable($key,$environment[$key])}
 $failed=@($rows | Where-Object Status -eq 'FAIL').Count
 $blocked=@($rows | Where-Object Status -in @('BLOCKED','MISSING','NOT_RUN')).Count
 $text=@('# Prompt 6 integration tooling regression',"Run $stamp; branch $(git branch --show-current).",'', '| Check | Status | Actual result | Evidence |','|---|---|---|---|')
 foreach($row in $rows){$text+="| $($row.Name) | $($row.Status) | $($row.Detail) | $($row.Evidence) |"}
 $text+="`nFAIL=$failed; BLOCKED/MISSING/NOT_RUN=$blocked. Installed object presence does not certify behavior or role security."
 $text | Set-Content "$dir/summary.md" -Encoding UTF8
 $rows | Export-Csv "$dir/checks.csv" -NoTypeInformation -Encoding UTF8
 Write-Output "REGRESSION|FAIL=$failed|BLOCKED=$blocked|report=$dir/summary.md"
}
if($failed){exit 1};if($blocked){exit 2};exit 0
