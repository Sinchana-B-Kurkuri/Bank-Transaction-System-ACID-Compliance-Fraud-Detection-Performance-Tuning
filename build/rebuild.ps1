param(
 [string]$Database='bank_txn',
 [ValidateSet('Standalone','Integrated')][string]$Mode,
 [switch]$WithSeed,
 [ValidateSet('Baseline','Optimized')][string]$IndexProfile='Baseline'
)
. "$PSScriptRoot/mysql_common.ps1"
Assert-BankDatabase $Database
$root=Split-Path $PSScriptRoot -Parent
$watch=[Diagnostics.Stopwatch]::StartNew()
try {
 Push-Location $root
 $bTables=@(Get-ChildItem 'schema/01_tables' -Filter '*.sql' | Where-Object Name -Match '^(10|11|12|13|14|15|16)_')
 if (!$Mode -and $env:BANK_TEST_BUILD_MODE) {
  if($env:BANK_TEST_BUILD_MODE -notin @('Standalone','Integrated')){throw 'Invalid BANK_TEST_BUILD_MODE test override.'}
  $Mode=$env:BANK_TEST_BUILD_MODE
 }
 if (!$Mode) { $Mode=if ($bTables.Count -eq 7) {'Integrated'} else {'Standalone'} }
 if ($Mode -eq 'Integrated' -and $bTables.Count -ne 7) { throw 'Integrated build requires all seven real Member B table files.' }
 if ($IndexProfile -eq 'Optimized' -and $Mode -ne 'Integrated') { throw 'Optimized requires Integrated mode and real B index definitions.' }
 $seed=@(Get-ChildItem 'data/seed' -Filter '*.sql' | Where-Object Name -Match '^\d+_' | Sort-Object @{Expression={ [int]($_.BaseName -split '_')[0] }},Name)
 if ($WithSeed -and !$seed.Count) { throw '-WithSeed requested but no data/seed/*.sql loaders exist.' }
 if ($env:BANK_TEST_ISOLATED_PREFIX) {
  # Rebuild is allowed only after the isolated owner marker has been established.
  $exists=@(Invoke-BankMysql -Sql "SELECT COUNT(*) FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='$Database';")[0]
  if ($exists -eq '1') {
   $owner=@(Invoke-BankMysql -Database $Database -Sql 'SELECT owner_token FROM _a_test_owner;')[0]
   if ($owner -cne $env:BANK_TEST_OWNER_TOKEN -or !$env:BANK_TEST_OWNER_TOKEN) { throw 'Refusing to rebuild a database not owned by this isolated run.' }
  }
 }
 Invoke-BankMysql -Sql "DROP DATABASE IF EXISTS $Database; CREATE DATABASE $Database CHARACTER SET utf8mb4;"
 if ($env:BANK_TEST_ISOLATED_PREFIX) { Invoke-BankMysql -Database $Database -Sql "CREATE TABLE _a_test_owner(owner_token CHAR(32) NOT NULL); INSERT INTO _a_test_owner VALUES('$env:BANK_TEST_OWNER_TOKEN');" | Out-Null }
 $build=if ($Mode -eq 'Standalone') {'build/run_all_A_standalone.sql'} else {'build/run_all.sql'}
 if ($IndexProfile -eq 'Optimized') { $build='build/run_all_optimized.sql' }
 Invoke-BankMysql -Database $Database -Sql "source $build"
 if ($WithSeed) {
  foreach ($file in $seed) {
   if ($Mode -eq 'Standalone' -and $file.Name -eq '03_fraud_rules.sql') { continue }
   $relative=$file.FullName.Substring($root.Length+1).Replace('\','/')
   Invoke-BankMysql -Database $Database -Sql "source $relative"
  }
 }
 $snapshot=if ($IndexProfile -eq 'Baseline') {'evidence/EV-B0-1.txt'} else {'evidence/EV-INDEX-OPTIMIZED.txt'}
 Invoke-BankMysql -Database $Database -Sql 'source schema/03_baseline_indexes/b0_snapshot.sql' | Set-Content (Get-BankEvidencePath $snapshot) -Encoding UTF8
 Write-Output "Rebuilt $Database ($Mode/$IndexProfile) in $($watch.Elapsed.TotalSeconds.ToString('F2')) seconds."
} catch { Write-Error $_; exit 1 } finally { Pop-Location }
