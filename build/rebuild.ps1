param(
 [string]$Database='bank_txn',
 [ValidateSet('Standalone','Integrated')][string]$Mode,
 [switch]$WithSeed
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
 $seed=@(Get-ChildItem 'data/seed' -Filter '*.sql' | Where-Object Name -Match '^\d+_' | Sort-Object @{Expression={ [int]($_.BaseName -split '_')[0] }},Name)
 if ($WithSeed -and !$seed.Count) { throw '-WithSeed requested but no data/seed/*.sql loaders exist.' }
 Invoke-BankMysql -Sql "DROP DATABASE IF EXISTS $Database; CREATE DATABASE $Database CHARACTER SET utf8mb4;"
 $build=if ($Mode -eq 'Standalone') {'build/run_all_A_standalone.sql'} else {'build/run_all.sql'}
 Invoke-BankMysql -Database $Database -Sql "source $build"
 if ($WithSeed) {
  foreach ($file in $seed) {
   $relative=$file.FullName.Substring($root.Length+1).Replace('\','/')
   Invoke-BankMysql -Database $Database -Sql "source $relative"
  }
 }
 Invoke-BankMysql -Database $Database -Sql 'source schema/03_baseline_indexes/b0_snapshot.sql' | Set-Content 'evidence/EV-B0-1.txt' -Encoding UTF8
 Write-Output "Rebuilt $Database ($Mode) in $($watch.Elapsed.TotalSeconds.ToString('F2')) seconds."
} catch { Write-Error $_; exit 1 } finally { Pop-Location }
