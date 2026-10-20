param()
. "$PSScriptRoot/../build/mysql_common.ps1"
$root=Split-Path $PSScriptRoot -Parent;Set-Location $root
$stamp=Get-Date -Format 'yyyyMMdd-HHmmss-fff';$dir=Join-Path $root "evidence/regression/$stamp"
[void][IO.Directory]::CreateDirectory($dir)
$rows=[Collections.Generic.List[object]]::new();$oldMode=$env:BANK_TEST_BUILD_MODE
$preserved=[Collections.Generic.List[object]]::new()
# Keep previous audit/experiment evidence byte-for-byte. New measurements go in this run directory.
foreach($path in @(git ls-files evidence)) {
 if(Test-Path -LiteralPath $path -PathType Leaf){$preserved.Add(@{Path=$path;Bytes=[IO.File]::ReadAllBytes((Join-Path $root $path))})}
}
function Report-Regression($Name,$Status,$Detail,$Evidence) {
 $script:rows.Add([pscustomobject]@{Name=$Name;Status=$Status;Detail=$Detail.Replace('|','/');Evidence=$Evidence})
 Write-Output "CHECK|$Status|$Name|$Detail"
}
function Invoke-RegressionChild([string]$File,[string[]]$Arguments,[string]$Name) {
 $ErrorActionPreference='Continue'
 $out=@(& powershell -NoProfile -File $File @Arguments 2>&1 | ForEach-Object {"$_"});$code=$LASTEXITCODE
 $ErrorActionPreference='Stop'
 $out | Set-Content (Join-Path $script:dir "$Name.txt") -Encoding UTF8
 $summary=($out | Where-Object {$_ -match '^TOTAL\|'} | Select-Object -Last 1)
 if(!$summary){$summary="PASS=$(@($out | Where-Object {$_ -like 'TEST|PASS|*'}).Count); FAIL=$(@($out | Where-Object {$_ -like 'TEST|FAIL|*'}).Count)"}
 return [pscustomobject]@{Code=$code;Summary=$summary;Output=$out;Evidence="evidence/regression/$script:stamp/$Name.txt"}
}
try {
 $b=@(Get-ChildItem schema/01_tables -File | Where-Object Name -Match '^(10|11|12|13|14|15|16)_.*\.sql$')
 $modes=@('Standalone');if($b.Count -eq 7){$modes+='Integrated'}else{Report-Regression 'Integrated build' 'BLOCKED' 'Seven real B tables unavailable' ''}
 foreach($mode in $modes) {
  $env:BANK_TEST_BUILD_MODE=$mode
  $r=Invoke-RegressionChild build/rebuild.ps1 @('-Database','bank_txn','-Mode',$mode,'-WithSeed') "$mode-build"
  Report-Regression "$mode rebuild" $(if($r.Code){'FAIL'}else{'PASS'}) $r.Summary $r.Evidence
  if($r.Code){continue}
  $snapshot=Join-Path $dir "$mode-B0.txt";Copy-Item evidence/EV-B0-1.txt $snapshot
  $r=Invoke-RegressionChild tests/run_tests.ps1 @('-Database','bank_txn','-NoRebuild') "$mode-suite"
  Report-Regression "$mode full suite" $(if($r.Code){'FAIL'}else{'PASS'}) $r.Summary $r.Evidence
  $out=@(Invoke-BankMysql -Database bank_txn -Sql 'SOURCE tests/integration/04_after_experiments.sql;')
  $out | Set-Content "$dir/$mode-invariants.txt" -Encoding UTF8
  Report-Regression "$mode invariants" $(if($out -match '^TEST\|FAIL'){'FAIL'}else{'PASS'}) 'Six summaries (I1,I1b,I2,I3,I4,I5)' "evidence/regression/$stamp/$mode-invariants.txt"
  $r=Invoke-RegressionChild build/release_strip_lab_hook.ps1 @() "$mode-release-generation"
  if($r.Code){Report-Regression "$mode release generation" 'FAIL' $r.Summary $r.Evidence}
  $r=Invoke-RegressionChild tests/p6_static.ps1 @('-Database','bank_txn','-Snapshot',$snapshot) "$mode-static"
  Report-Regression "$mode static and B0" $(if($r.Code){'FAIL'}else{'PASS'}) $r.Summary $r.Evidence
 }
 $selected=if($modes -contains 'Integrated'){'Integrated'}else{'Standalone'}
 $env:BANK_TEST_BUILD_MODE=$selected
 $r=Invoke-RegressionChild tests/run_release.ps1 @('-Mode',$selected) 'release-suite'
 Report-Regression 'Release procedure suite' $(if($r.Code){'FAIL'}else{'PASS'}) $r.Summary $r.Evidence
 Copy-Item evidence/EV-REL-1.txt "$dir/EV-REL-1.txt"
 # A real B schema is not a substitute for the unmerged B runtime module.
 $required=@('fn_distance_km','fn_amount_zscore','fn_txn_count_window','fn_is_odd_hour','fn_account_age_days','fn_txn_risk_score','fn_risk_level','sp_evaluate_fraud')
 $list=($required | ForEach-Object {"'$_'"}) -join ','
 $installed=@(Invoke-BankMysql -Database bank_txn -Sql "SELECT ROUTINE_NAME FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA=DATABASE() AND ROUTINE_NAME IN ($list);")
 $missing=@($required | Where-Object {$installed -notcontains $_})
 Report-Regression 'B fraud runtime' $(if($missing.Count){'BLOCKED'}else{'PASS'}) $(if($missing.Count){'Missing: '+($missing -join ', ')}else{'All required routines installed'}) ''
 $fraud=@(Invoke-BankMysql -Database bank_txn -Sql "SELECT TRIGGER_NAME,ACTION_ORDER FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA=DATABASE() AND EVENT_OBJECT_TABLE='Transactions' AND ACTION_TIMING='AFTER' AND EVENT_MANIPULATION='INSERT' AND TRIGGER_NAME<>'trg_transactions_ai_audit';")
 if(!$fraud.Count){Report-Regression 'Fraud trigger ordering/rollback integration' 'BLOCKED' 'No B fraud trigger exists; absence is not an ordering pass' ''}
 else {
  $order=[int]@(Invoke-BankMysql -Database bank_txn -Sql "SELECT ACTION_ORDER FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA=DATABASE() AND TRIGGER_NAME='trg_transactions_ai_audit';")[0]
  $good=@($fraud | Where-Object {[int](($_ -split "`t")[1]) -le $order}).Count -eq 0
  $source=@(Get-ChildItem triggers -Recurse -Filter *.sql | Where-Object {[IO.File]::ReadAllText($_.FullName) -match '(?is)CREATE\s+TRIGGER.*?FOLLOWS\s+trg_transactions_ai_audit'})
  Report-Regression 'Fraud trigger ordering' $(if($good -and $source.Count){'PASS'}else{'FAIL'}) 'Server action order and source FOLLOWS both required' ''
 }
 $security=@(Get-ChildItem security -Recurse -Filter *.sql)
 Report-Regression 'B RBAC integration' $(if($security.Count){'BLOCKED'}else{'BLOCKED'}) 'No executable B RBAC acceptance suite available; A restricted-login tests do not certify B roles' ''
 $command=Get-Command (Join-Path $root 'experiments/run_all_auto.ps1')
 if($command.Parameters.ContainsKey('Quick')) {
  $lab=@(Invoke-BankMysql -Database bank_txn_scratch -Sql "SELECT COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA=DATABASE() AND ROUTINE_NAME='sp_lab_stress_loop';")[0]
  if($lab -eq '1') {
   $r=Invoke-RegressionChild experiments/run_all_auto.ps1 @('-Database','bank_txn_scratch','-Quick') 'experiments-quick'
   Report-Regression 'Quick experiments' $(if($r.Code){'FAIL'}else{'PASS'}) $r.Summary $r.Evidence
  } else {Report-Regression 'Quick experiments' 'BLOCKED' 'No installed lab objects/accounts; conditional step not executed' ''}
 } else {Report-Regression 'Quick experiments' 'BLOCKED' 'Aggregate does not implement -Quick; not invoking an argument it would silently ignore. Existing drivers rebuild Standalone; out of Prompt 6 edit scope.' ''}
 foreach($db in @('bank_txn','bank_txn_scratch')) {
  $out=@(Invoke-BankMysql -Database $db -Sql 'SOURCE tests/integration/04_after_experiments.sql;')
  $out | Set-Content "$dir/final-$db.txt" -Encoding UTF8
  Report-Regression "Final $db invariants" $(if($out -match '^TEST\|FAIL'){'FAIL'}else{'PASS'}) 'Six actual summaries; Quick not executed unless separately reported PASS' "evidence/regression/$stamp/final-$db.txt"
 }
} catch {Report-Regression 'Regression orchestration' 'FAIL' $_.Exception.Message ''}
finally {
 foreach($entry in $preserved){
  $path=Join-Path $root $entry.Path
  if(Test-Path $path){
   $current=[IO.File]::ReadAllBytes($path)
   if([Convert]::ToBase64String($current) -cne [Convert]::ToBase64String($entry.Bytes)) {
    $copy=Join-Path $dir ('generated/'+$entry.Path);[void][IO.Directory]::CreateDirectory((Split-Path $copy -Parent));[IO.File]::WriteAllBytes($copy,$current)
    [IO.File]::WriteAllBytes($path,$entry.Bytes)
   }
  }
 }
 $env:BANK_TEST_BUILD_MODE=$oldMode
 $text=@('# Prompt 6 regression — measured results', '', "Run: $stamp; branch: $(git branch --show-current). Native Windows PowerShell/MySQL; no simulated concurrency proof.", '', '| Check | Status | Actual result | Evidence |','|---|---|---|---|')
 foreach($row in $rows){$text+="| $($row.Name) | $($row.Status) | $($row.Detail) | $($row.Evidence) |"}
 $failed=@($rows | Where-Object Status -eq 'FAIL').Count;$blocked=@($rows | Where-Object Status -eq 'BLOCKED').Count
 $text+="`nFAIL=$failed; BLOCKED=$blocked. Missing modules and unsupported Quick are never labeled passed."
 [IO.File]::WriteAllText((Join-Path $dir 'summary.md'),($text -join "`n"),[Text.UTF8Encoding]::new($false))
 [IO.File]::WriteAllText((Join-Path $root "evidence/regression/$stamp.md"),($text -join "`n"),[Text.UTF8Encoding]::new($false))
 Write-Output "REGRESSION|FAIL=$failed|BLOCKED=$blocked|report=evidence/regression/$stamp.md"
}
if($failed){exit 1};if($blocked){exit 2};exit 0
