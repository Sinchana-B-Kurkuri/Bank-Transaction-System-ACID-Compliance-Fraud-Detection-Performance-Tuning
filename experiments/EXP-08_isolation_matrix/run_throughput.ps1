param([string]$Database='bank_txn_scratch',[switch]$Quick,[int]$Queries=500)
. "$PSScriptRoot/../lib/Common.ps1"
. "$PSScriptRoot/../lib/MySqlSlapConnection.ps1"
$HardwareFile='evidence/EV-EXP08-hardware.json'
Initialize-Lab $Database
$dir=New-EvidenceDir 'EXP-08'
$slap=Join-Path (Split-Path (Get-MySqlPath) -Parent) mysqlslap.exe
$help=& $slap --help
Save-Text "$dir/mysqlslap-help.txt" ($help -join "`n")
if (($help -join ' ') -notmatch '--no-drop') { throw 'mysqlslap lacks required --no-drop safety option.' }
$levels=if ($Quick) { @('READ-COMMITTED','REPEATABLE-READ') } else { @('READ-UNCOMMITTED','READ-COMMITTED','REPEATABLE-READ','SERIALIZABLE') }
$concurrency=if ($Quick) { @(5,25) } else { @(5,10,25,50) }
$iterations=if ($Quick) { 1 } else { 3 }
$old=@(Invoke-MySql $Database -Sql 'SELECT @@GLOBAL.transaction_isolation;')[0]
$monitor=@(Invoke-MySql $Database -Sql "SELECT STATUS FROM information_schema.INNODB_METRICS WHERE NAME='lock_deadlocks';")[0]
$hardwareStatus='MEASURED using Get-CimInstance'
try {
 $config=Get-CimInstance Win32_Processor | Select-Object Name,NumberOfCores,NumberOfLogicalProcessors | Out-String
 $config+=Get-CimInstance Win32_ComputerSystem | Select-Object TotalPhysicalMemory | Out-String
} catch {
 $config="Get-CimInstance unavailable: $($_.Exception.Message)`n"
 if (Test-Path -LiteralPath $HardwareFile) {
  $hardware=[IO.File]::ReadAllText((Resolve-Path -LiteralPath $HardwareFile))
  $record=$hardware | ConvertFrom-Json
  if ([DateTimeOffset]::Parse($record.measured_at).Date -ne [DateTime]::Today) { throw 'Hardware evidence is not from today; refresh it with Get-CimInstance.' }
  $config+=$hardware
  $hardwareStatus="MEASURED from authorized same-day Get-CimInstance record $HardwareFile"
 } else {
  $hardwareStatus='NEEDS MANUAL VERIFICATION: Get-CimInstance access denied; no measured hardware record supplied'
 }
}
$config+=@(Invoke-MySql $Database -Sql "SELECT VERSION(),NOW(),@@GLOBAL.transaction_isolation,@@GLOBAL.innodb_buffer_pool_size,@@GLOBAL.max_connections,@@GLOBAL.sync_binlog,@@GLOBAL.innodb_flush_log_at_trx_commit;") -join "`n"
Save-Text "$dir/config.txt" $config
$rows=@()
$connection=Get-MySqlSlapConnection
try {
 if ($monitor -ne 'enabled') { Invoke-MySql $Database -Sql "SET GLOBAL innodb_monitor_enable='lock_deadlocks';" | Out-Null }
 foreach ($level in $levels) {
  Invoke-MySql $Database -Sql "SET GLOBAL transaction_isolation='$level';" | Out-Null
  foreach ($p in $concurrency) {
   $metrics="SELECT COUNT(*) FROM Transactions WHERE status='Completed'; SELECT COUNT FROM information_schema.INNODB_METRICS WHERE NAME='lock_deadlocks'; SELECT COUNT(*) FROM bank_lab.Experiment_Log WHERE db_name=DATABASE() AND exp_id='RETRY'; SELECT COALESCE(SUM(COUNT_STAR),0) FROM performance_schema.events_statements_summary_by_digest WHERE SCHEMA_NAME=DATABASE() AND DIGEST_TEXT LIKE 'CALL %sp_lab_random_transfer%'; SELECT COALESCE(SUM(SUM_TIMER_WAIT),0) FROM performance_schema.events_statements_summary_by_digest WHERE SCHEMA_NAME=DATABASE() AND DIGEST_TEXT LIKE 'CALL %sp_lab_random_transfer%';"
   $before=@(Invoke-MySql $Database -Sql $metrics -OutputFile "$dir/$level-$p-metrics-before.txt")
   $args=$connection.Arguments+@("--create-schema=$Database",'--no-drop',"--concurrency=$p","--iterations=$iterations","--number-of-queries=$Queries",'--query=CALL sp_lab_random_transfer();')
   $started=[DateTimeOffset]::UtcNow
   $watch=[Diagnostics.Stopwatch]::StartNew()
   $pi=[Diagnostics.ProcessStartInfo]::new(); $pi.FileName=$slap; $pi.Arguments=($args | ForEach-Object { ConvertTo-BankNativeArgument $_ }) -join ' '; $pi.UseShellExecute=$false; $pi.CreateNoWindow=$true; $pi.RedirectStandardOutput=$true; $pi.RedirectStandardError=$true
   if ($null -ne $connection.Password) { $pi.EnvironmentVariables['MYSQL_PWD']=$connection.Password }
   $proc=[Diagnostics.Process]::Start($pi); $o=$proc.StandardOutput.ReadToEndAsync(); $e=$proc.StandardError.ReadToEndAsync(); $proc.WaitForExit(); $watch.Stop()
   $finished=[DateTimeOffset]::UtcNow; $elapsed=($finished-$started).TotalSeconds
   $output=$o.Result; $errorText=$e.Result
   $pi.EnvironmentVariables.Remove('MYSQL_PWD')
   Save-Text "$dir/$level-$p.stdout.txt" $output; Save-Text "$dir/$level-$p.stderr.txt" $errorText
   if ($proc.ExitCode) { throw "mysqlslap exited $($proc.ExitCode): $errorText" }
   $after=@(Invoke-MySql $Database -Sql $metrics -OutputFile "$dir/$level-$p-metrics-after.txt")
   $latency=$null; if ($output -match 'Average number of seconds to run all queries:\s+([\d.]+)') { $latency=[double]::Parse($Matches[1],[Globalization.CultureInfo]::InvariantCulture) }
   $delta=[int64]$after[0]-[int64]$before[0]
   $serverCalls=[int64]$after[3]-[int64]$before[3]
   $serverLatency=if ($serverCalls -gt 0) { ([decimal]$after[4]-[decimal]$before[4])/1000000000000/$serverCalls } else { $null }
   $timing=if ($latency*$iterations -gt $elapsed*1.2) { 'CLIENT TIMING EXCEEDS WALL TIME: use wall-based throughput; verify reported latency manually' } else { 'OK' }
   $rows+=[pscustomobject]@{isolation=$level;concurrency=$p;iterations=$iterations;queries_requested=$Queries;started_utc=$started.ToString('o');finished_utc=$finished.ToString('o');elapsed_seconds=$elapsed;stopwatch_seconds=$watch.Elapsed.TotalSeconds;completed_ledger_rows=$delta;successful_transfers=$delta/2;ledger_rows_per_second=$delta/$elapsed;transfers_per_second=$delta/2/$elapsed;mean_run_seconds=$latency;estimated_mean_query_seconds=$latency*$p/$Queries;server_calls=$serverCalls;server_mean_call_seconds=$serverLatency;timing_note=$timing;deadlocks=[int64]$after[1]-[int64]$before[1];retry_rows=[int64]$after[2]-[int64]$before[2]}
  }
 }
 Assert-LabInvariants $Database $dir
} finally {
 $connection.Password=$null
 Invoke-MySql $Database -Sql "SET GLOBAL transaction_isolation='$old';" | Out-Null
 if ($monitor -ne 'enabled') { Invoke-MySql $Database -Sql "SET GLOBAL innodb_monitor_disable='lock_deadlocks';" | Out-Null }
 Invoke-MySql $Database -Sql "SELECT @@GLOBAL.transaction_isolation; SELECT STATUS FROM information_schema.INNODB_METRICS WHERE NAME='lock_deadlocks';" -OutputFile "$dir/globals-restored.txt" | Out-Null
}
$rows | Export-Csv evidence/EV-EXP08-throughput.csv -NoTypeInformation -Encoding UTF8
$rows | Export-Csv "$dir/throughput.csv" -NoTypeInformation -Encoding UTF8
$md=@('# Measured mysqlslap throughput','',"Raw/config: $dir",'',
 '| Isolation | Clients | Iterations | Transfers | Transfers/sec (wall) | Server mean CALL ms | Reported mean batch sec | Deadlocks | Retry rows |',
 '|---|---:|---:|---:|---:|---:|---:|---:|---:|')
foreach ($row in $rows) { $md+="| $($row.isolation) | $($row.concurrency) | $($row.iterations) | $($row.successful_transfers) | $([math]::Round($row.transfers_per_second,2)) | $([math]::Round($row.server_mean_call_seconds*1000,3)) | $($row.mean_run_seconds) | $($row.deadlocks) | $($row.retry_rows) |" }
$md+="`nRates use UTC wall duration, independently checked by Stopwatch. CSV retains native mysqlslap timing disagreement flags; reported batch time is not verified per-call latency. Server mean CALL uses performance_schema digest counter/timer deltas (sample counts in CSV). Completed ledger rows / 2 counts successful transfers. Global deadlock deltas require an otherwise idle server. Hardware/config and before/after metrics are in the raw directory."
Save-Text evidence/EV-EXP08-throughput.md ($md -join "`n")
Save-Text "$dir/throughput.md" ([IO.File]::ReadAllText((Join-Path $script:RepoRoot 'evidence/EV-EXP08-throughput.md')))
Complete-Experiment $PSScriptRoot $dir @("RESULT|EXP-08|ALL|throughput_runs|$($rows.Count)","RESULT|EXP-08|ALL|hardware|$hardwareStatus")
