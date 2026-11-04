param([string]$Database='bank_txn_scratch',[string]$StateFile='backup/out/recovery_state.json')
. "$PSScriptRoot/Common.ps1"
Assert-Scratch $Database
& powershell -NoProfile -File build/rebuild.ps1 -Database $Database -WithSeed
if ($LASTEXITCODE) {throw 'Scratch rebuild failed.'}
Invoke-MySql -Database $Database -File experiments/lab_objects/install.sql | Out-Null
Invoke-MySql -Database $Database -File experiments/lab_objects/setup_lab_accounts.sql | Out-Null
$dir=New-EvidenceDir 'EXP-16'
Invoke-BankMysql -Sql 'SELECT VERSION(),NOW(6),@@innodb_flush_log_at_trx_commit,@@sync_binlog,@@innodb_doublewrite,@@log_bin;' | ForEach-Object {$_} | Set-Content "$dir/environment.txt" -Encoding UTF8
[void][IO.Directory]::CreateDirectory((Join-Path $script:RepoRoot 'backup/out'))
$dump=Join-Path $script:RepoRoot ('backup/out/full_'+(Get-Date -Format 'yyyyMMdd_HHmmss_fff')+'.sql')
$help=Invoke-RecoveryTool mysqldump @('--help')
$coordinate=if($help -match '--source-data') {'--source-data=2'} elseif($help -match '--master-data') {'--master-data=2'} else {throw 'No supported binlog coordinate option in mysqldump.'}
Invoke-BankMysql -Sql 'FLUSH LOGS;' | Out-Null
$watch=[Diagnostics.Stopwatch]::StartNew()
Invoke-RecoveryTool mysqldump @("--defaults-extra-file=$env:BANK_MYSQL_CNF",'--single-transaction','--routines','--triggers','--events','--set-gtid-purged=OFF','--no-tablespaces','--databases',$Database,$coordinate,"--result-file=$dump") | Out-Null
$watch.Stop()
$snapshot=Get-RecoverySnapshot $Database
$audit=Join-Path $script:RepoRoot 'backup/out/audit-S0.jsonl'
Save-AuditBaseline $Database $audit
$snapshot.AuditBaseline=$audit
# Read only the coordinate comment, never put the dump in evidence.
$line=Select-String -LiteralPath $dump -Pattern '^-- CHANGE (REPLICATION SOURCE|MASTER) TO' | Select-Object -First 1
if (!$line -or $line.Line -notmatch "(?:SOURCE|MASTER)_LOG_FILE='([^']+)', (?:SOURCE|MASTER)_LOG_POS=(\d+)") {throw 'Dump coordinate comment missing.'}
$start=@{File=$Matches[1];Position=[long]$Matches[2]}
$state=@{Database=$Database;Dump=$dump;Evidence=$dir;DumpBytes=(Get-Item -LiteralPath $dump).Length;DumpSeconds=$watch.Elapsed.TotalSeconds;Start=$start;S0=$snapshot;S1=$null;S2=$null;BeforeOops=$null;LossTime=$null}
Save-RecoveryState $state $StateFile
Save-Text "$dir/backup.json" ($state | ConvertTo-Json -Depth 10)
Write-Output "RESULT|EXP-16|backup|bytes=$($state.DumpBytes)|coordinate=$($start.File):$($start.Position)|state=$StateFile"
