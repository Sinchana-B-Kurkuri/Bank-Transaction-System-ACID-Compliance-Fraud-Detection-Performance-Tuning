param(
 [ValidateSet('Start','Stop')][string]$Action='Start',
 [string]$SessionFile='demo/out/session.json'
)
# No users/grants/global settings. Only collision-checked owner-marked demo schemas.
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
. "$root/build/mysql_common.ps1"
$saved=@{};foreach($k in @('BANK_TEST_ISOLATED_PREFIX','BANK_TEST_OWNER_TOKEN','BANK_TEST_EVIDENCE_DIR')){$saved[$k]=[Environment]::GetEnvironmentVariable($k)}
$created=[Collections.Generic.List[string]]::new()
try {
 Push-Location $root
 $SessionFile=[IO.Path]::GetFullPath($SessionFile)
 if($Action -eq 'Start'){
  if(Test-Path -LiteralPath $SessionFile){throw 'Session file exists; stop that owned session or select a fresh SessionFile. Never adopts existing schemas.'}
  $prefix='bank_a_ci_demo_'+[guid]::NewGuid().ToString('N').Substring(0,12)
  $state=[ordered]@{Prefix=$prefix;Owner=[guid]::NewGuid().ToString('N');Evidence=Join-Path $root ('evidence/reviews/final-demo/runs/'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff')+'-'+[guid]::NewGuid().ToString('N'));Database="${prefix}_main";Status='starting'}
 }else{
  $state=Get-Content -LiteralPath $SessionFile -Raw | ConvertFrom-Json
  if($state.Prefix -cnotmatch '^bank_a_ci_demo_[a-f0-9]{12}$' -or $state.Database -cne "$($state.Prefix)_main"){throw 'Invalid demo session names'}
  if($state.Status -eq 'cleaned'){throw 'Session has already been cleaned'}
 }
 $env:BANK_TEST_ISOLATED_PREFIX=$state.Prefix;$env:BANK_TEST_OWNER_TOKEN=$state.Owner;$env:BANK_TEST_EVIDENCE_DIR=$state.Evidence
 Assert-BankIsolatedContext
 [void][IO.Directory]::CreateDirectory($state.Evidence)
 $names=@("$($state.Prefix)_main","$($state.Prefix)_scratch","$($state.Prefix)_lab")
 if($Action -eq 'Start'){
  foreach($db in $names){if(@(Invoke-BankMysql -Sql "SELECT COUNT(*) FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='$db';")[0] -ne '0'){throw 'Collision; refusing existing database'}}
  foreach($db in $names){
   Invoke-BankMysql -Sql "CREATE DATABASE $db CHARACTER SET utf8mb4;" | Out-Null;$created.Add($db)
   Invoke-BankMysql -Database $db -Sql "CREATE TABLE _a_test_owner(owner_token CHAR(32) NOT NULL);INSERT INTO _a_test_owner VALUES('$($state.Owner)');" | Out-Null
  }
  & powershell -NoProfile -File build/rebuild.ps1 -Database $state.Database -Mode Integrated -WithSeed -IndexProfile Baseline
  if($LASTEXITCODE){throw 'Demo integrated build failed'}
  $state.Status='ready'
  [void][IO.Directory]::CreateDirectory((Split-Path $SessionFile -Parent))
  [IO.File]::WriteAllText($SessionFile,($state|ConvertTo-Json),[Text.UTF8Encoding]::new($false))
  Write-Output "DEMO|READY|$($state.Database)|$SessionFile"
  Write-Output 'NON-SECURITY DEMO by default: no restricted accounts have been provisioned.'
 }else{
  # Verify all markers before dropping any schema. A missing/mismatched marker aborts.
  foreach($db in $names){Assert-BankDatabase $db;if(@(Invoke-BankMysql -Database $db -Sql 'SELECT owner_token FROM _a_test_owner;')[0] -cne $state.Owner){throw "Owner mismatch: $db"}}
  foreach($db in $names){Invoke-BankMysql -Sql "DROP DATABASE $db;" | Out-Null
   if(@(Invoke-BankMysql -Sql "SELECT COUNT(*) FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='$db';")[0] -ne '0'){throw 'Cleanup incomplete'}
   Write-Output "TEST|PASS|demo owned cleanup $db|zero remaining schema"
  }
  $state.Status='cleaned';[IO.File]::WriteAllText($SessionFile,($state|ConvertTo-Json),[Text.UTF8Encoding]::new($false))
 }
}catch{
 if($Action -eq 'Start'){
  foreach($db in $created){
   # No broad cleanup: an unsuccessful marker check preserves the schema for inspection.
   if(@(Invoke-BankMysql -Database $db -Sql 'SELECT owner_token FROM _a_test_owner;')[0] -ceq $state.Owner){Invoke-BankMysql -Sql "DROP DATABASE $db;" | Out-Null}
  }
 }
 throw
}finally{foreach($k in $saved.Keys){[Environment]::SetEnvironmentVariable($k,$saved[$k])};Pop-Location}
