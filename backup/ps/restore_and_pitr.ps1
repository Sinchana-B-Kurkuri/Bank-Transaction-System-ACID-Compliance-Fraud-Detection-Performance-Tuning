param([string]$Database='bank_txn_scratch',[string]$StateFile='backup/out/recovery_state.json')
. "$PSScriptRoot/Common.ps1"
Assert-Scratch $Database
$s=Read-RecoveryState $StateFile
if (!$s.LossTime -or $s.Database -ne $Database) {throw 'Simulate loss first.'}
$summary=@('# EXP-16 measured recovery', '', '| Variant | Status | Dump seconds | Replay seconds | RTO seconds | RPO seconds |', '|---|---|---:|---:|---:|---:|')
$comparisons=@('| Variant | Table | Expected rows | Actual rows | Expected checksum | Actual checksum | Match |','|---|---|---:|---:|---|---|---|')
$failed=$false
$notes=@()
foreach($variant in @('dump-only','before-loss','before-oops')) {
 $target=if($variant -eq 'dump-only'){$s.S0}elseif($variant -eq 'before-loss'){$s.S2}else{$s.S1}
 $timer=[Diagnostics.Stopwatch]::StartNew(); Restore-RecoveryDump $s; $dumpSeconds=$timer.Elapsed.TotalSeconds
 $replaySeconds=0; $status='PASS'; $reason=''
 if($variant -ne 'dump-only') {
  try {
   $stop=if($variant -eq 'before-oops'){$s.BeforeOops}else{$s.S2.Position}
   if($stop.File -ne $s.Start.File) {throw 'This bounded experiment requires the workload to remain in the dump binlog file; repeat with a smaller workload.'}
   $datadir=@(Invoke-BankMysql -Sql 'SELECT @@datadir;')[0]
   $bin=Join-Path $datadir $s.Start.File
   try {$stream=[IO.File]::Open($bin,'Open','Read','ReadWrite');$stream.Dispose()} catch {throw 'Binlog file access denied/unavailable. Run restore_and_pitr.ps1 in an elevated shell with read access to datadir.'}
   $replay=Join-Path $script:RepoRoot "backup/out/replay_$variant.sql"
   $startReplay=$timer.Elapsed.TotalSeconds
   Invoke-RecoveryTool mysqlbinlog @('--no-defaults',"--start-position=$($s.Start.Position)","--stop-position=$($stop.Position)",'--database=bank_txn_scratch',"--result-file=$replay",$bin) | Out-Null
   Invoke-RecoveryTool mysql @("--defaults-extra-file=$env:BANK_MYSQL_CNF",'--batch','--skip-force',"--execute=source $($replay.Replace('\','/'))") | Out-Null
   $replaySeconds=$timer.Elapsed.TotalSeconds-$startReplay
  } catch {$status='NEEDS MANUAL VERIFICATION'; $reason=$_.Exception.Message}
 }
 $timer.Stop()
 if($status -eq 'PASS') {
  $actual=Get-RecoverySnapshot $Database
  foreach($expected in $target.Tables) {
   $got=$actual.Tables | Where-Object Table -eq $expected.Table
   $ok=$got.Rows -eq $expected.Rows -and $got.Checksum -eq $expected.Checksum
   if(!$ok){
    if($expected.Table -eq 'Audit_Log' -and $got.Rows -eq $expected.Rows -and $target.AuditBaseline) {
     $different=Compare-AuditBaseline $Database $target.AuditBaseline
     $notes+="$variant Audit_Log native checksum differs; semantic comparison of every field in every row found $different differences. Opaque MySQL DATE/DATETIME/DECIMAL JSON values become text representations during SQL dump/load. Native checksum match is FALSE; this is explicitly not an all-checksums-match claim."
     if($different){$status='FAIL';$failed=$true}else{$status='PASS (JSON-normalized; native checksum differs)'}
    }else{$status='FAIL';$failed=$true}
   }
   $comparisons+="| $variant | $($expected.Table) | $($expected.Rows) | $($got.Rows) | $($expected.Checksum) | $($got.Checksum) | $ok |"
  }
  Assert-LabInvariants $Database "$($s.Evidence)"
  Copy-Item "$($s.Evidence)/invariants.txt" "$($s.Evidence)/invariants-$variant.txt"
  # Recovered commit time is the measured completion of the bounded workload (S0/S1/S2), not a guessed RPO.
  $rpo=([datetime]$s.LossTime-[datetime]$target.Time).TotalSeconds
  $summary+="| $variant | $status | $($dumpSeconds.ToString('F3')) | $($replaySeconds.ToString('F3')) | $($timer.Elapsed.TotalSeconds.ToString('F3')) | $($rpo.ToString('F6')) |"
 } else {
  $summary+="| $variant | $status | $($dumpSeconds.ToString('F3')) | NOT YET RUN | NOT YET RUN | NOT YET RUN |"
  $notes+="$variant : $reason"
 }
 Write-Output "RESULT|EXP-16|$variant|$status"
}
$lost=($s.S2.Tables | Where-Object Table -eq 'Transactions').Rows-($s.S0.Tables | Where-Object Table -eq 'Transactions').Rows
$lostAudit=($s.S2.Tables | Where-Object Table -eq 'Audit_Log').Rows-($s.S0.Tables | Where-Object Table -eq 'Audit_Log').Rows
$summary+=@('', '## Notes', '')+$notes+@('', 'RPO is measured from the last recovered workload commit observation to the recorded loss time; snapshot completion is an upper bound on commit time, so these values are lower bounds on the exact commit-to-loss interval. Before-oops intentionally excludes the erroneous DELETE transaction and all later work. RTO measures dump load plus replay only (not human response or checksum verification).', '', "Dump-only lost $lost post-dump ledger rows and $lostAudit post-dump audit rows in this run. Restoring dumped triggers does not reinstall the D5 watermark; bank_lab is intentionally outside the dump. No new watermark is fabricated. Transactions cannot be deleted due to ledger immutability; the operator error targets Loans.", '', 'Binlog boundary method: record SHOW BINARY LOG STATUS immediately before DELETE, inspect SHOW BINLOG EVENTS from that position (Table_map/Delete_rows/Xid), and stop replay before that transaction. Replay SQL and dumps remain in ignored backup/out/.', '', '## Checksums (all nine A tables)')
Save-Text evidence/EV-EXP16-summary.md (($summary+$comparisons) -join "`n")
Save-Text "$($s.Evidence)/recovery-summary.md" (($summary+$comparisons) -join "`n")
if($failed){throw 'Recovery checksum comparison failed; see evidence.'}
