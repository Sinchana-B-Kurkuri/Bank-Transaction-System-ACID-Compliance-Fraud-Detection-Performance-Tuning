param([switch]$ReproduceOriginal)
$ErrorActionPreference='Stop'
$root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
# Reuse only the existing quoting/include helpers. Invoke-BankMysql and its
# protected-target allowlist are NEVER called, overridden, or weakened here.
. "$root/build/mysql_common.ps1"
$stamp=(Get-Date -Format 'yyyyMMdd-HHmmss-fff')+'-'+[guid]::NewGuid().ToString('N')
$directory=Join-Path $root "evidence/error1222/$stamp"
[void][IO.Directory]::CreateDirectory($directory)
$utf8=[Text.UTF8Encoding]::new($false)
$nonce=[guid]::NewGuid().ToString('N')
$owner=[guid]::NewGuid().ToString('N')
$database=$null;$owned=$false;$marker=$false;$pass=0;$fail=0
$results=[Collections.Generic.List[string]]::new()
function Save-Proof([string]$Name,[string]$Text) {
 [IO.File]::WriteAllText((Join-Path $script:directory $Name),$Text,$script:utf8)
}
function Test-Result([string]$Name,[bool]$Ok,[string]$Detail) {
 $line="TEST|$(if($Ok){'PASS'}else{'FAIL'})|$Name|$Detail"
 if($Ok){$script:pass++}else{$script:fail++}
 $script:results.Add($line);Write-Output $line
}
function Assert-OwnedName {
 if($script:database -cnotmatch '\Abank_b_1222_[a-f0-9]{32}_(before|after)\z'){throw 'Refusing a non-disposable database name.'}
}
function Convert-IsolatedSql([string]$Sql) {
 Assert-OwnedName
 $Sql=Expand-BankSqlSource -Sql $Sql
 # Only the helper namespace is relocated. Stored routine/trigger logic is intact.
 $Sql=[regex]::Replace($Sql,'(?i)\bbank_lab\b',$script:database)
 if($Sql -match '(?i)\bbank_txn(?:_scratch)?\b|\bbank_lab\b'){throw 'Protected schema reference in expanded SQL.'}
 $body=[regex]::Replace($Sql,'(?s)/\*.*?\*/|(?m)^\s*--[^\r\n]*','')
 if($body -match '(?i)\b(?:CREATE|ALTER|DROP)\s+(?:USER|ROLE)\b|\b(?:GRANT|REVOKE|SHUTDOWN|KILL)\b|\bSET\s+(?:GLOBAL|PERSIST)\b|\bFLUSH\b'){throw 'Administrative/server operation forbidden in focused harness.'}
 foreach($m in [regex]::Matches($body,'(?i)\b(?:CREATE|DROP)\s+(?:DATABASE|SCHEMA)\s+(?:IF\s+(?:NOT\s+)?EXISTS\s+)?`?(\w+)')) {
  if($m.Groups[1].Value -cne $script:database){throw 'DDL targets a database outside this test.'}
 }
 foreach($m in [regex]::Matches($body,'(?i)\bUSE\s+`?(\w+)')) {
  if($m.Groups[1].Value -cne $script:database){throw 'USE outside this test.'}
 }
 return $Sql
}
function Invoke-IsolatedSql([string]$Sql,[string]$Name,[switch]$Admin) {
 $inputSql=Convert-IsolatedSql $Sql
 Save-Proof "$Name.sql" $inputSql
 $target=if($Admin){'information_schema'}else{$script:database}
 $arguments=@("--defaults-extra-file=$script:optionFile",'--batch','--raw','--skip-column-names','--default-character-set=utf8mb4','--skip-force',"--database=$target")
 $start=[Diagnostics.ProcessStartInfo]::new()
 $start.FileName=$script:client
 $start.Arguments=($arguments | ForEach-Object {ConvertTo-BankNativeArgument $_}) -join ' '
 $start.WorkingDirectory=$script:root;$start.UseShellExecute=$false;$start.CreateNoWindow=$true
 $start.RedirectStandardInput=$true;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
 $start.StandardOutputEncoding=$script:utf8;$start.StandardErrorEncoding=$script:utf8
 $process=[Diagnostics.Process]::new();$process.StartInfo=$start
 try {
  [void]$process.Start()
  $out=$process.StandardOutput.ReadToEndAsync();$err=$process.StandardError.ReadToEndAsync()
  $writeError=$null
  try {$bytes=$script:utf8.GetBytes($inputSql+"`n");$process.StandardInput.BaseStream.Write($bytes,0,$bytes.Length)}
  catch {$writeError=$_.Exception.Message}
  finally {$process.StandardInput.BaseStream.Close()}
  if(!$process.WaitForExit(60000)) {
   # Only this child mysql CLIENT is terminated; never mysqld or a service.
   $process.Kill();$process.WaitForExit();throw 'Focused mysql client exceeded its 60-second deadline.'
  }
  $stdout=$out.GetAwaiter().GetResult();$stderr=$err.GetAwaiter().GetResult()
  Save-Proof "$Name.stdout.txt" $stdout;Save-Proof "$Name.stderr.txt" $stderr
  return [pscustomobject]@{Code=$process.ExitCode;Out=$stdout;Err=$stderr;WriteError=$writeError}
 } finally {$process.Dispose()}
}
function Invoke-Required([string]$Sql,[string]$Name,[switch]$Admin) {
 $r=Invoke-IsolatedSql -Sql $Sql -Name $Name -Admin:$Admin
 if($r.Code -ne 0 -or $r.WriteError){throw "$Name failed (mysql exit $($r.Code)): $($r.Err) $($r.WriteError)"}
 return $r
}
function Remove-OwnedDatabase([string]$Case) {
 if(!$script:owned){return}
 Assert-OwnedName
 if($script:marker) {
  $r=Invoke-Required 'SELECT owner_token FROM _error1222_owner;' "$Case-owner-check"
  if($r.Out.Trim() -cne $script:owner){throw 'Owner marker mismatch; retaining database rather than dropping it.'}
 }
 Invoke-Required "DROP DATABASE $script:database;" "$Case-cleanup" -Admin | Out-Null
 $r=Invoke-Required "SELECT COUNT(*) FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='$script:database';" "$Case-cleanup-verify" -Admin
 Test-Result "$Case isolated cleanup" ($r.Out.Trim() -eq '0') 'Fresh owned database removed'
 $script:owned=$false;$script:marker=$false
}
try {
 Push-Location $root
 if(!$env:BANK_MYSQL_CNF -or !(Test-Path -LiteralPath $env:BANK_MYSQL_CNF -PathType Leaf)){throw 'Set BANK_MYSQL_CNF to an existing private option file.'}
 $optionFile=(Resolve-Path -LiteralPath $env:BANK_MYSQL_CNF).ProviderPath
 $client=if($env:BANK_MYSQL_BIN){(Resolve-Path -LiteralPath $env:BANK_MYSQL_BIN).ProviderPath}else{(Get-Command mysql.exe -CommandType Application -ErrorAction Stop).Source}
 # Dependency closure for the seed + audit/guard + fraud call chain, not a full build.
 $files=@('schema/04_lab/01_bank_lab.sql')
 $files+=@(Get-ChildItem schema/01_tables -File -Filter '*.sql' | Where-Object Name -Match '^(0[1-9]|1[0-4])_' | Sort-Object Name | ForEach-Object {$_.FullName.Substring($root.Length+1).Replace('\','/')})
 $files+=@('schema/02_constraints/01_core_constraints.sql','schema/02_constraints/02_cross_module_fks.sql')
 $files+=@('fn_approval_threshold','fn_generate_reference','fn_txn_risk_score','fn_txn_count_window','fn_risk_level') | ForEach-Object {"functions/$_.sql"}
 $files+=@('sp_resolve_actor','sp_internal_assert_staff','sp_internal_authorize','sp_internal_insert_ledger','sp_internal_post_single','sp_internal_post_transfer','sp_internal_record_failed','sp_register_customer','sp_open_account','sp_deposit','sp_withdraw','sp_disburse_loan','sp_set_account_status','sp_transfer_funds','sp_reconcile_balances') | ForEach-Object {"procedures/$_.sql"}
 $tail=@(Get-ChildItem triggers/guards,triggers/audit -File -Filter '*.sql' | Sort-Object FullName | ForEach-Object {$_.FullName.Substring($root.Length+1).Replace('\','/')})
 $tail+=@('triggers/99_record_audit_install.sql','data/seed/01_reference_data.sql','data/seed/03_fraud_rules.sql','triggers/fraud/trg_transactions_ai_fraud_evaluate.sql')
 $seed=[IO.File]::ReadAllText((Join-Path $root 'data/seed/02_tiny_seed.sql'))
 $seedTail='(?s)\r?\nCALL p3_load_tiny_seed\(\);\s*DROP PROCEDURE p3_load_tiny_seed;\s*\z'
 if([regex]::Matches($seed,$seedTail).Count -ne 1){throw 'Tiny seed trailer changed; review harness before executing.'}
 $definition=[regex]::Replace($seed,$seedTail,"`n")
 $current=[IO.File]::ReadAllText((Join-Path $root 'procedures/sp_evaluate_fraud.sql'))
 $cases=@('after');$original=$null
 if($ReproduceOriginal) {
  $original=(& git show '053eb19:procedures/sp_evaluate_fraud.sql') -join "`n"
  if($LASTEXITCODE -ne 0){throw 'Original corrective revision 053eb19 unavailable.'}
  $cases=@('before','after')
 }
 Save-Proof 'sources.txt' (($files+@('procedures/sp_evaluate_fraud.sql')+$tail+@('data/seed/02_tiny_seed.sql','tests/regression/error1222_seed.sql')) -join "`n")
 foreach($case in $cases) {
  $database="bank_b_1222_${nonce}_$case"
  $owned=$false;$marker=$false
  try {
   # Validate all expanded installation/test SQL before creating the database.
   $prefix="SET SESSION sql_mode='STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';`n"+ (($files | ForEach-Object {"SOURCE $_;"}) -join "`n")
   $evaluator=if($case -eq 'before'){$original}else{$current}
   $install=(Expand-BankSqlSource $prefix)+"`n"+$evaluator+"`n"+(Expand-BankSqlSource (($tail | ForEach-Object {"SOURCE $_;"}) -join "`n"))+"`n"+$definition
   $null=Convert-IsolatedSql $install
   $null=Convert-IsolatedSql 'SOURCE tests/regression/error1222_seed.sql;'
   $r=Invoke-Required 'SELECT VERSION(),@@version_comment,NOW(6),DATABASE();' "$case-environment" -Admin
   if($r.Out -notmatch '^8\.4\.11(?:\s|-)'){throw 'This reproduction requires actual MySQL 8.4.11.'}
   $r=Invoke-Required "SELECT COUNT(*) FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='$database';" "$case-preflight" -Admin
   if($r.Out.Trim() -ne '0'){throw 'Refusing an existing disposable database.'}
   Invoke-Required "CREATE DATABASE $database CHARACTER SET utf8mb4;" "$case-create" -Admin | Out-Null
   $owned=$true
   Invoke-Required "CREATE TABLE _error1222_owner(owner_token CHAR(32) NOT NULL); INSERT INTO _error1222_owner VALUES('$owner');" "$case-owner" | Out-Null
   $marker=$true
   Invoke-Required $install "$case-install" | Out-Null
   if($case -eq 'before') {
    $r=Invoke-IsolatedSql 'CALL p3_load_tiny_seed();' 'before-seed-call'
    Test-Result 'original tiny seed reproduces 1222' ($r.Code -ne 0 -and $r.Err -match 'ERROR 1222 \(21000\)') $r.Err.Trim()
    if($r.Code -eq 0 -or $r.Err -notmatch 'ERROR 1222 \(21000\)'){throw 'Original failure was not reproduced as expected.'}
    $r=Invoke-Required "SELECT CONCAT((SELECT COUNT(*) FROM Customers),'|',(SELECT COUNT(*) FROM Accounts),'|',(SELECT COUNT(*) FROM Transactions),'|',(SELECT COUNT(*) FROM Audit_Log));" 'before-rollback-state'
    Test-Result 'original first opening rolled back' ($r.Out.Trim() -eq '6|0|0|0') 'Six earlier customer commits remain; failed opening leaves no account, ledger or audit rows'
   } else {
    $r=Invoke-Required 'SOURCE tests/regression/error1222_seed.sql;' 'after-regression'
    $lines=@($r.Out -split '\r?\n' | Where-Object {$_ -like 'TEST|*'})
    foreach($line in $lines){$results.Add($line);Write-Output $line;if($line -like 'TEST|PASS|*'){$pass++}else{$fail++}}
    if($lines.Count -lt 20){throw 'Regression emitted fewer checks than expected.'}
    # Record actual installed qualification; none may reference the protected helper.
    $r=Invoke-Required "SELECT ROUTINE_NAME,ROUTINE_DEFINITION FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA=DATABASE(); SELECT TRIGGER_NAME,ACTION_ORDER,ACTION_STATEMENT FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA=DATABASE();" 'after-installed-objects'
    Test-Result 'installed routines target disposable schema' ($r.Out -notmatch '(?i)\bbank_(?:txn(?:_scratch)?|lab)\b') 'Installed nested routine/trigger definitions contain no protected schema references'
   }
  } finally {Remove-OwnedDatabase $case}
 }
} catch {Test-Result 'error1222 harness execution' $false $_.Exception.Message}
finally {
 if($owned){try {Remove-OwnedDatabase 'final'}catch{Test-Result 'isolated cleanup failure' $false $_.Exception.Message}}
 $summary="TOTAL|PASS=$pass|FAIL=$fail"
 $results.Add($summary);Save-Proof 'summary.txt' ($results -join "`n")
 Write-Output $summary;Write-Output "EVIDENCE|$directory"
 Pop-Location
}
if($fail){exit 1}
