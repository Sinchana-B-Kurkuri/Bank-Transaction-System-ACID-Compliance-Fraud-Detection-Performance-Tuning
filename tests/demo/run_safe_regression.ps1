# Safe demo regression: actual A isolated context/builds, SQL tests and vetted safe children.
# Never invokes the full runner's fixed/global account tests. No new roles/users/grants.
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '../..')).ProviderPath
. "$root/build/mysql_common.ps1"
$dir=Join-Path $root 'evidence/reviews/final-demo/runs';[void][IO.Directory]::CreateDirectory($dir);$dir=Join-Path $dir ('isolated-'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff')+'-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($dir)
$prefix='bank_a_ci_check_'+[guid]::NewGuid().ToString('N').Substring(0,12)
$saved=@{};foreach($key in @('BANK_TEST_ISOLATED_PREFIX','BANK_TEST_OWNER_TOKEN','BANK_TEST_EVIDENCE_DIR','BANK_TEST_BUILD_MODE')){$saved[$key]=[Environment]::GetEnvironmentVariable($key)}
$owned=[Collections.Generic.List[string]]::new();$proof=[Collections.Generic.List[string]]::new()
$rows=[Collections.Generic.List[object]]::new();$pass=0;$fail=0
$utf8=[Text.UTF8Encoding]::new($false)
function Record([string]$Name,[bool]$Ok,[string]$Detail){
 $line="TEST|$(if($Ok){'PASS'}else{'FAIL'})|$Name|$Detail"
 if($Ok){$script:pass++}else{$script:fail++};$script:proof.Add($line);Write-Output $line
}
function Save([string]$Name,[string[]]$Output){[IO.File]::WriteAllLines((Join-Path $script:dir $Name),$Output,$script:utf8)}
function Child([string]$File,[string[]]$Extra,[string]$Name){
 $ErrorActionPreference='Continue'
 $out=@(& powershell -NoProfile -File $File @Extra 2>&1 | ForEach-Object {"$_"});$code=$LASTEXITCODE
 $ErrorActionPreference='Stop';Save "$Name.txt" $out
 return [pscustomobject]@{Code=$code;Out=$out}
}
function Count-Results([string]$Name,[string[]]$Out,[int]$Code){
 $p=@($Out | Where-Object {$_ -like 'TEST|PASS|*'}).Count;$f=@($Out | Where-Object {$_ -like 'TEST|FAIL|*'}).Count
 $script:rows.Add([pscustomobject]@{Name=$Name;Pass=$p;Fail=$f;Exit=$Code})
 Record $Name ($Code -eq 0 -and $p -gt 0 -and $f -eq 0) "PASS=$p;FAIL=$f;EXIT=$Code"
}
function Invariants([string]$Db,[string]$Name){
 $out=@(Invoke-BankMysql -Database $Db -Sql 'SOURCE tests/integration/04_after_experiments.sql;');Save "$Name.txt" $out
 Count-Results $Name $out 0
 if(@($out -like 'TEST|PASS|*').Count -ne 6){throw 'Expected exactly six invariant results.'}
}
try{
 Push-Location $root
 $env:BANK_TEST_ISOLATED_PREFIX=$prefix
 $env:BANK_TEST_OWNER_TOKEN=[guid]::NewGuid().ToString('N')
 $env:BANK_TEST_EVIDENCE_DIR=$dir
 Assert-BankIsolatedContext
 $names=@("${prefix}_main","${prefix}_scratch","${prefix}_lab")
 foreach($db in $names){Assert-BankDatabase $db;$n=@(Invoke-BankMysql -Sql "SELECT COUNT(*) FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='$db';")[0];if($n -ne '0'){throw 'Existing isolated name; refusing adoption.'}}
 foreach($db in $names){
  Invoke-BankMysql -Sql "CREATE DATABASE $db CHARACTER SET utf8mb4;" | Out-Null;$owned.Add($db)
  Invoke-BankMysql -Database $db -Sql "CREATE TABLE _a_test_owner(owner_token CHAR(32) NOT NULL);INSERT INTO _a_test_owner VALUES('$env:BANK_TEST_OWNER_TOKEN');" | Out-Null
 }
 $database=$names[0];$scratch=$names[1]
 $r=Child build/release_strip_lab_hook.ps1 @() 'release-generation'
 Record 'release source generation' ($r.Code -eq 0) 'Static generation only; no banking database rebuilt'
 $manifest=Import-Csv tests/component_tests.csv
 foreach($mode in @('Standalone','Integrated')){
  $env:BANK_TEST_BUILD_MODE=$mode
  $r=Child build/rebuild.ps1 @('-Database',$database,'-Mode',$mode,'-WithSeed','-IndexProfile','Baseline') "$mode-build"
  Record "$mode actual owner-scoped rebuild" ($r.Code -eq 0) ($r.Out | Select-Object -Last 1)
  if($r.Code){throw 'Owned baseline build failed.'}
  $snapshot=Get-BankEvidencePath 'evidence/EV-B0-1.txt';Copy-Item -LiteralPath $snapshot -Destination (Join-Path $dir "$mode-B0.txt")
  foreach($folder in @('schema','functions','triggers','procedures','invariants','integration')){
   foreach($file in Get-ChildItem "tests/$folder" -File -Filter '*.sql' | Where-Object Name -Match '^\d\d_' | Sort-Object Name){
    $relative=$file.FullName.Substring($root.Length+1).Replace('\','/')
    if($mode -eq 'Standalone' -and @($manifest | Where-Object {$_.Path -eq $relative -and $_.Mode -eq 'Integrated'}).Count){
     $line="SKIP|$relative|Standalone has no B runtime";$proof.Add($line);Write-Output $line;continue
    }
    $restore=$false;$code=0;$out=@()
    try{
     if($relative -eq 'tests/schema/01_negative_constraints.sql'){Invoke-BankMysql -Database $database -Sql 'DROP TRIGGER trg_transactions_bu_immutable;' | Out-Null;$restore=$true}
     $out=@(Invoke-BankMysql -Database $database -Sql "SET @test_run_id='$mode-merge';`nSOURCE $relative;")
    }catch{$code=1;$out=@($_.Exception.Message,[string]$_.Exception.Data['RawOutput'])}
    finally{if($restore){Invoke-BankMysql -Database $database -Sql 'SOURCE triggers/guards/trg_transactions_bu_immutable.sql;' | Out-Null}}
    $name="$mode-$folder-$($file.BaseName)";Save "$name.txt" $out;Count-Results $name $out $code
   }
  }
  foreach($file in @('tests/schema/03_source_order.ps1','tests/schema/04_mysql_wrapper.ps1','tests/schema/05_isolated_context.ps1','tests/schema/06_quick_arguments.ps1','tests/integration/07_real_b_schema.ps1','tests/procedures/14_statement_resultsets.ps1','tests/procedures/17_statement_after_interest.ps1')){
   $name="$mode-$([IO.Path]::GetFileNameWithoutExtension($file))"
   $r=Child $file @('-Database',$database) $name;Count-Results $name $r.Out $r.Code
  }
  $r=Child tests/p6_static.ps1 @('-Database',$database,'-Snapshot',(Join-Path $dir "$mode-B0.txt")) "$mode-p6-static"
  Count-Results "$mode-p6-static" $r.Out $r.Code
  Invariants $database "$mode-six-invariants"
 }
 # Existing runtime acceptance is observed, including honest undeployed-role blockers.
 $r=Child tests/runtime_acceptance.ps1 @('-Database',$database,'-Mode','Integrated') 'runtime-acceptance'
 $bad=@($r.Out | Where-Object {$_ -like 'ACCEPTANCE|FAIL|*'}).Count
 $pending=@($r.Out | Where-Object {$_ -match '^ACCEPTANCE\|(MISSING|BLOCKED)\|'}).Count
 Record 'runtime behavior acceptance without global grants' ($r.Code -in @(0,2) -and $bad -eq 0) "behavior failures=$bad; pending role checks=$pending; exit=$($r.Code); not a complete-role acceptance claim"
 $r=Child experiments/run_all_auto.ps1 @('-Database',$database,'-Quick') 'bounded-quick'
 Count-Results 'bounded Quick real sessions' $r.Out $r.Code
 Invariants $database 'post-Quick-six-invariants'
 $r=Child build/rebuild.ps1 @('-Database',$scratch,'-Mode','Integrated','-WithSeed','-IndexProfile','Optimized') 'optimized-build'
 Record 'actual explicit optimized entry build' ($r.Code -eq 0) 'Uses run_all_optimized.sql on fresh owned scratch; no protected scratch target'
 if($r.Code){throw 'Owned optimized build failed.'}
 $idx=@(Invoke-BankMysql -Database $scratch -Sql "SELECT DISTINCT INDEX_NAME FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND INDEX_NAME LIKE 'idx!_%' ESCAPE '!' ORDER BY INDEX_NAME;")
 Save 'optimized-indexes.txt' $idx;Record 'explicit optimized indexes' ($idx.Count -eq 7) 'Seven named B performance indexes; no performance claim'
 $out=@(Invoke-BankMysql -Database $scratch -Sql 'SOURCE benchmarks/01_query_plan_comparison.sql;');Save 'optimized-explain.txt' $out
 Record 'optimized native EXPLAIN compatibility' (@($out | Where-Object {($_ -split "`t").Count -ge 12}).Count -eq 3) 'Three actual EXPLAIN SELECTs, no EXPLAIN ANALYZE or throughput'
 Invariants $scratch 'optimized-six-invariants'
}catch{Record 'isolated verification execution' $false $_.Exception.Message}
finally{
 foreach($db in $owned){
  try{
   $token=@(Invoke-BankMysql -Database $db -Sql 'SELECT owner_token FROM _a_test_owner;')[0]
   if($token -cne $env:BANK_TEST_OWNER_TOKEN){throw 'Owner mismatch; database retained.'}
   Invoke-BankMysql -Sql "DROP DATABASE $db;" | Out-Null
   $n=@(Invoke-BankMysql -Sql "SELECT COUNT(*) FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='$db';")[0]
   Record "owned cleanup $db" ($n -eq '0') 'Owner verified; zero remaining schema'
  }catch{Record "cleanup $db" $false $_.Exception.Message}
 }
 $rows | Export-Csv (Join-Path $dir 'test-populations.csv') -NoTypeInformation -Encoding UTF8
 Save 'summary.txt' ([string[]]($proof+@("TOTAL|CHECK_PASS=$pass|CHECK_FAIL=$fail")))
 foreach($key in $saved.Keys){[Environment]::SetEnvironmentVariable($key,$saved[$key])}
 Pop-Location
 Write-Output "TOTAL|CHECK_PASS=$pass|CHECK_FAIL=$fail";Write-Output "EVIDENCE|$dir"
}
if($fail){exit 1}
