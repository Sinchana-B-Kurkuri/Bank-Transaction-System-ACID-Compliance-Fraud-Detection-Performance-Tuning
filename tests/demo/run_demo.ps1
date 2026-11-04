param([string]$Python=$env:BANK_PYTHON_BIN)
$ErrorActionPreference='Stop'
$root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if(!$Python){$c=Get-Command python -CommandType Application -ErrorAction SilentlyContinue;if($c){$Python=$c.Source}else{throw 'Set BANK_PYTHON_BIN to Python 3.10+ executable'}}
. "$root/experiments/lib/Common.ps1"
$dir=Join-Path $root ('evidence/reviews/final-demo/runs/workflow-'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff')+'-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($dir)
$session=Join-Path $dir 'session.json';$pass=0;$fail=0;$state=$null;$transferProbe=$false;$originalTransfer=$null
$saved=@{};foreach($key in @('BANK_TEST_ISOLATED_PREFIX','BANK_TEST_OWNER_TOKEN','BANK_TEST_EVIDENCE_DIR')){$saved[$key]=[Environment]::GetEnvironmentVariable($key)}
function Check([string]$Name,[bool]$Ok,[string]$Detail){
 $line="TEST|$(if($Ok){'PASS'}else{'FAIL'})|$Name|$Detail";Add-Content (Join-Path $dir 'checks.txt') $line -Encoding UTF8;Write-Output $line
 if($Ok){$script:pass++}else{$script:fail++;throw $line}
}
function Db([string]$Sql){
 Add-Content "$dir/driver-queries.sql" $Sql -Encoding UTF8
 return @(Invoke-BankMysql -Database $state.Database -Sql $Sql)
}
function Invoke-DemoCli([string]$Name,[string[]]$CliArgs,[int]$Expected=0){
 $start=[Diagnostics.ProcessStartInfo]::new();$start.FileName=$Python
 $arguments=@('demo/bank_cli.py','--database',$state.Database)
 if($Name -ne 'restricted-mode-refuses-admin'){$arguments+='--non-security-demo'}
 $arguments+=$CliArgs
 $start.Arguments=($arguments|ForEach-Object{ConvertTo-BankNativeArgument $_}) -join ' '
 $start.WorkingDirectory=$root;$start.UseShellExecute=$false;$start.CreateNoWindow=$true
 $start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
 $start.StandardOutputEncoding=[Text.UTF8Encoding]::new($false);$start.StandardErrorEncoding=$start.StandardOutputEncoding
 $start.EnvironmentVariables['PYTHONUTF8']='1'
 $process=[Diagnostics.Process]::new();$process.StartInfo=$start
 try{
  [void]$process.Start();$stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync()
  if(!$process.WaitForExit(40000)){throw 'CLI outer deadline expired; no server process killed'}
  $text=$stdout.GetAwaiter().GetResult();$errorText=$stderr.GetAwaiter().GetResult();$code=$process.ExitCode
 }finally{$process.Dispose()}
 Save-Text "$dir/$Name.stderr.txt" $errorText
 Save-Text "$dir/$Name.stdout.txt" $text
 Check "CLI $Name" ($code -eq $Expected) "exit=$code expected=$Expected; actual stdout/stderr retained"
 return @($text -split '\r?\n')
}
try{
 Push-Location $root
 & powershell -NoProfile -File demo/start_demo.ps1 -SessionFile $session
 if($LASTEXITCODE){throw 'Demo startup failed'}
 $state=Get-Content $session -Raw | ConvertFrom-Json
 $env:BANK_TEST_ISOLATED_PREFIX=$state.Prefix;$env:BANK_TEST_OWNER_TOKEN=$state.Owner;$env:BANK_TEST_EVIDENCE_DIR=$dir
 Assert-BankIsolatedContext
 Save-Text "$dir/environment.txt" (@(Db "SELECT VERSION(),@@version_comment,USER(),NOW(6);SHOW VARIABLES WHERE Variable_name IN ('transaction_isolation','innodb_flush_log_at_trx_commit','sync_binlog','log_bin','performance_schema');") -join "`n")
 try{
  $cpu=Get-CimInstance Win32_Processor | Select-Object Name,NumberOfCores,NumberOfLogicalProcessors
  $machine=Get-CimInstance Win32_ComputerSystem | Select-Object TotalPhysicalMemory
  Save-Text "$dir/hardware.json" (@{Cpu=$cpu;Memory=$machine;OS=[Environment]::OSVersion.ToString();Python=(& $Python --version)}|ConvertTo-Json -Depth 4)
 }catch{Save-Text "$dir/hardware-unavailable.txt" $_.Exception.Message}
 Invoke-DemoCli 'launch' @('whoami') | Out-Null
 Invoke-DemoCli 'restricted-mode-refuses-admin' @('whoami') 1 | Out-Null
 Check 'restricted CLI refuses role simulation' ((Get-Content "$dir/restricted-mode-refuses-admin.stderr.txt" -Raw) -match 'No recognized active banking role') 'unprovisioned administrative session needs explicit non-security flag'
 Invoke-DemoCli 'accounts' @('accounts') | Out-Null
 Invoke-DemoCli 'registration' @('register','--name','Synthetic Demo Customer','--dob','1992-01-01','--email','demo.customer@example.invalid','--phone','9000099991','--address','Synthetic demo address','--id-proof','SYN-PAN-DEMO-0001','--id-type','PAN') | Out-Null
 $customer=[int]@(Db "SELECT customer_id FROM Customers WHERE email='demo.customer@example.invalid';")[0]
 $branch=[int]@(Db "SELECT branch_id FROM Branches WHERE ifsc_code='SYNB0000001';")[0]
 $type=[int]@(Db "SELECT account_type_id FROM Account_Types WHERE type_name='Savings';")[0]
 $teller=[int]@(Db "SELECT employee_id FROM Employees WHERE branch_id=$branch AND role='Teller' LIMIT 1;")[0]
 $manager=[int]@(Db "SELECT employee_id FROM Employees WHERE branch_id=$branch AND role='Manager' LIMIT 1;")[0]
 Invoke-DemoCli 'opening' @('open','--customer',"$customer",'--branch',"$branch",'--type',"$type",'--initial','200000','--number','DEMO-0001','--employee',"$teller") | Out-Null
 $account=[int]@(Db "SELECT account_id FROM Accounts WHERE account_number='DEMO-0001';")[0]
 $to=[int]@(Db "SELECT account_id FROM Accounts WHERE account_number='SEED-0002';")[0]
 Invoke-DemoCli 'deposit' @('deposit',"$account",'100') | Out-Null
 Invoke-DemoCli 'withdraw' @('withdraw',"$account",'25') | Out-Null
 Invoke-DemoCli 'transfer' @('transfer',"$account","$to",'200') | Out-Null
 Check 'CLI workflow balance' (@(Db "SELECT balance FROM Accounts WHERE account_id=$account;")[0] -eq '199875.00') 'opening200000 +100 -25 -200 =199875'
 Invoke-DemoCli 'invalid-overdraft' @('withdraw',"$account",'9999999') 1 | Out-Null
 Check 'original MySQL error visible' ((Get-Content "$dir/invalid-overdraft.stderr.txt" -Raw) -match '5004') 'native insufficient-funds errno preserved'
 Invoke-DemoCli 'statement' @('statement',"$account",'--from',(Get-Date -Format 'yyyy-MM-dd'),'--to',(Get-Date -Format 'yyyy-MM-dd')) | Out-Null
 $lastStatement=@(Get-Content "$dir/statement.stdout.txt"|Where-Object {($_ -split "`t").Count -eq 8 -and $_ -notmatch '^transaction_id'})[-1] -split "`t"
 Check 'CLI statement running balance' ($lastStatement[4] -eq '199875.00' -and $lastStatement[7] -eq '199875.00') 'last Completed balance_after equals returned window running_balance'
 Invoke-DemoCli 'history' @('history',"$account") | Out-Null
 Invoke-DemoCli 'fraud-queue' @('flags') | Out-Null
 $flag=[int]@(Db "SELECT MIN(f.flag_id) FROM Fraud_Flags f JOIN Transactions t ON t.transaction_id=f.transaction_id WHERE t.account_id=$account;")[0]
 Invoke-DemoCli 'fraud-review' @('review',"$flag",'UnderReview','--manager',"$manager") | Out-Null
 Invoke-DemoCli 'fraud-confirm' @('review',"$flag",'Confirmed','--manager',"$manager") | Out-Null
 Check 'fraud review committed' (@(Db "SELECT CONCAT(flag_status,'|',reviewed_by) FROM Fraud_Flags WHERE flag_id=$flag;")[0] -eq "Confirmed|$manager") 'real public manager-review API, privileged demo caller'
 Invoke-DemoCli 'loan' @('loan',"$customer",'500','--account',"$account",'--rate','8','--months','12') | Out-Null
 # Existing System callers cannot request approval: temporarily map this actual
 # admin session in this owned DB only. This is an actor-map diagnostic, NOT RBAC.
 Db "INSERT INTO DB_User_Map(db_login,actor_type,customer_id) VALUES(USER(),'Customer',$customer);" | Out-Null
 try{Invoke-DemoCli 'approval-request' @('request-approval',"$account","$to",'100000','--customer',"$customer") | Out-Null}
 finally{Db 'DELETE FROM DB_User_Map WHERE db_login=USER();' | Out-Null}
 $approval=[int]@(Db "SELECT MAX(approval_id) FROM Transaction_Approvals WHERE from_account_id=$account;")[0]
 Invoke-DemoCli 'approval-decide' @('decide-approval',"$approval",'Approved','--manager',"$manager") | Out-Null
 Check 'approved money movement' (@(Db "SELECT balance FROM Accounts WHERE account_id=$account;")[0] -eq '100375.00') 'loan+500 and approved100000; paired ledger transaction'
 Invoke-DemoCli 'audit' @('audit') | Out-Null
 Invoke-DemoCli 'reconcile' @('reconcile') | Out-Null
 Check 'opening audit coverage' (@(Db "SELECT COUNT(*) FROM Audit_Log WHERE table_name='Accounts' AND record_pk='$account' AND action_type='INSERT' AND db_session_user=USER();")[0] -eq '1') 'one actual account INSERT audit with session USER'
 # Controlled normal and suspicious observations on a separate account. Trusted
 # branch100 has score0; untrusted Online6000 after opening has score100.
 Invoke-DemoCli 'normal-account' @('open','--customer',"$customer",'--branch',"$branch",'--type',"$type",'--initial','2000','--number','DEMO-NORMAL','--employee',"$teller") | Out-Null
 $normal=[int]@(Db "SELECT account_id FROM Accounts WHERE account_number='DEMO-NORMAL';")[0]
 Db "INSERT INTO Devices(customer_id,device_fingerprint,device_type,first_seen_at,last_seen_at,is_trusted) VALUES($customer,REPEAT('a',64),'Synthetic',NOW(),NOW(),TRUE);" | Out-Null
 $device=[int]@(Db "SELECT device_id FROM Devices WHERE device_fingerprint=REPEAT('a',64);")[0]
 Invoke-DemoCli 'normal-deposit' @('deposit',"$normal",'100','--channel','Branch','--employee',"$teller",'--device',"$device") | Out-Null
 $normalTx=[int64]@(Db "SELECT MAX(transaction_id) FROM Transactions WHERE account_id=$normal;")[0]
 Check 'normal transaction no flags' (@(Db "SELECT COUNT(*) FROM Fraud_Flags WHERE transaction_id=$normalTx;")[0] -eq '0') 'trusted Branch100, count2 below velocity3; final transaction score0'
 Check 'approved helper probe30' (@(Db "SELECT fn_txn_risk_score(100,'Online',FALSE,0);")[0] -eq '30.00') '+20 untrusted +10 digital'
 Invoke-DemoCli 'suspicious-deposit' @('deposit',"$normal",'6000') | Out-Null
 $tx=[int64]@(Db "SELECT MAX(transaction_id) FROM Transactions WHERE account_id=$normal;")[0]
 $score=@(Db "SELECT MAX(risk_score) FROM Fraud_Flags WHERE transaction_id=$tx;")[0]
 Check 'suspicious transaction score100' ($score -eq '100.00') 'base50 + amount20 + untrusted20 + digital10 capped100; local-risk/velocity flags follow'
 $before=@(Db "SELECT CONCAT(COUNT(*),'|',SUM(risk_score)) FROM Fraud_Flags WHERE transaction_id=$tx;")[0]
 Db "CALL sp_evaluate_fraud($tx);CALL sp_evaluate_fraud($tx);" | Out-Null
 Check 'reevaluation stable' (@(Db "SELECT CONCAT(COUNT(*),'|',SUM(risk_score)) FROM Fraud_Flags WHERE transaction_id=$tx;")[0] -eq $before) 'two actual calls; no new transaction or profile feedback'
 Save-Text "$dir/fraud-observations.txt" (@(Db "SELECT rule_code,weight,param_json FROM Fraud_Rules ORDER BY rule_id;SELECT f.flag_id,r.rule_code,f.risk_score,fn_risk_level(f.risk_score),f.evidence FROM Fraud_Flags f JOIN Fraud_Rules r ON r.rule_id=f.rule_id WHERE transaction_id=$tx ORDER BY f.flag_id;SELECT fn_distance_km(12.9,77.6,19.0,72.8),fn_is_odd_hour('2026-10-20 02:00:00');") -join "`n")
 # Bounded real isolation probes: writer rolls back, reader has a short deadline.
 $base=@(Db "SELECT balance FROM Accounts WHERE account_id=$account;")[0]
 foreach($level in @('READ UNCOMMITTED','READ COMMITTED','REPEATABLE READ','SERIALIZABLE')){
  $tag=$level.Replace(' ','_');$probeDir="$dir/isolation-$tag";[void][IO.Directory]::CreateDirectory($probeDir)
  $a=Start-MySqlSession -Database $state.Database -Name 'writer' -Directory $probeDir -Sql "START TRANSACTION;UPDATE Accounts SET balance=balance+7 WHERE account_id=$account;SELECT SLEEP(4);ROLLBACK;"
  $b=Start-MySqlSession -Database $state.Database -Name 'reader' -Directory $probeDir -Sql "SELECT SLEEP(1);SET SESSION TRANSACTION ISOLATION LEVEL $level;SET SESSION innodb_lock_wait_timeout=1;START TRANSACTION;SELECT CONCAT('READ|',balance) FROM Accounts WHERE account_id=$account;ROLLBACK;"
  Wait-Sessions -Sessions @($a,$b) -TimeoutSeconds 15 -AllowErrors
  $read=Get-Content $b.LabStdout -Raw;$err=Get-Content $b.LabStderr -Raw
  $ok=if($level -eq 'READ UNCOMMITTED'){$read -match ('READ\|'+([decimal]$base+7).ToString('F2'))}elseif($level -eq 'SERIALIZABLE'){$err -match '1205'}else{$read -match ('READ\|'+[regex]::Escape($base))}
  Check "real isolation $level" ($ok -and $a.ExitCode -eq 0) "writer rollback; reader errno/block/read retained; expected SERIALIZABLE1205 only"
 }
 # No global deadlock logging changes: actual opposite naive locks, then retry.
 # Reuse EXP-10's first-lock scheduling probe, ONLY in the owned database's
 # mode3 routine instance. Ordered modes and shipping SQL are unchanged.
 $originalTransfer=[IO.File]::ReadAllText((Join-Path $root 'procedures/sp_internal_post_transfer.sql'))
 $needle='SELECT account_id INTO v_lock FROM Accounts WHERE account_id=v_first FOR UPDATE;'
 if(([regex]::Matches($originalTransfer,[regex]::Escape($needle))).Count -ne 1){throw 'First-lock probe anchor changed'}
 $probe=$originalTransfer.Replace($needle,$needle+"`n IF p_lab_mode=3 THEN SELECT SLEEP(IFNULL(@lab_first_lock_sleep,1)) INTO v_sleep; END IF;")
 Save-Text "$dir/mode3-scheduling-probe.sql" $probe
 $transferProbe=$true;Db "DROP PROCEDURE sp_internal_post_transfer;`n$probe" | Out-Null
 $aId=[int]@(Db "SELECT account_id FROM Accounts WHERE account_number='SEED-0001';")[0]
 $bId=$to;$deadDir="$dir/deadlock";[void][IO.Directory]::CreateDirectory($deadDir)
 $sessions=@();foreach($pair in @(@($aId,$bId),@($bId,$aId))){$sessions+=Start-MySqlSession -Database $state.Database -Directory $deadDir -Name "naive-$($sessions.Count)" -Sql "SET @lab_sleep_seconds=1;SET SESSION innodb_lock_wait_timeout=5;CALL sp_transfer_funds($($pair[0]),$($pair[1]),1,'Online',NULL,NULL,NULL,3,@g,@d,@c);"}
 Wait-Sessions $sessions -TimeoutSeconds 20 -AllowErrors
 $errors=($sessions|ForEach-Object{Get-Content $_.LabStderr -Raw}) -join "`n"
 Check 'real naive deadlock victim' ($errors -match '1213' -and @($sessions|Where-Object ExitCode -eq 0).Count -eq 1) 'one real MySQL1213 victim; no simulated errno'
 $retryBefore=[int]@(Db "SELECT COUNT(*) FROM $($state.Prefix)_lab.Experiment_Log WHERE exp_id='RETRY';")[0]
 $sessions=@();foreach($pair in @(@($aId,$bId),@($bId,$aId))){$sessions+=Start-MySqlSession -Database $state.Database -Directory $deadDir -Name "retry-$($sessions.Count)" -Sql "SET @lab_sleep_seconds=0.5;SET SESSION innodb_lock_wait_timeout=5;CALL sp_transfer_funds_retry($($pair[0]),$($pair[1]),1,'Online',NULL,NULL,NULL,3,5,@g,@d,@c,@tries);SELECT CONCAT('ATTEMPTS|',@tries);"}
 Wait-Sessions $sessions -TimeoutSeconds 20
 $retryAfter=[int]@(Db "SELECT COUNT(*) FROM $($state.Prefix)_lab.Experiment_Log WHERE exp_id='RETRY';")[0]
 Check 'real deadlock retry completes' ($retryAfter -gt $retryBefore) "two native sessions success; new retry log rows=$($retryAfter-$retryBefore)"
 Save-Text "$dir/deadlock/retry-rows.txt" ((Db "SELECT event_type,detail FROM $($state.Prefix)_lab.Experiment_Log WHERE exp_id='RETRY';") -join "`n")
 Db "DROP PROCEDURE sp_internal_post_transfer;`n$originalTransfer" | Out-Null;$transferProbe=$false
 # Warmed per-statement timings on tiny data, not a performance improvement claim.
 $measure=[Collections.Generic.List[object]]::new()
 Save-Text "$dir/benchmark-row-counts.txt" (@(Db 'SELECT COUNT(*) FROM Accounts;SELECT COUNT(*) FROM Transactions;SELECT COUNT(*) FROM Fraud_Flags;SELECT COUNT(*) FROM Transaction_Approvals;') -join "`n")
 $queries=@("SELECT transaction_id,amount,status,transaction_timestamp FROM Transactions WHERE account_id=$account AND transaction_timestamp>=CURRENT_DATE-INTERVAL 30 DAY ORDER BY transaction_timestamp DESC","SELECT flag_id,transaction_id,risk_score,created_at FROM Fraud_Flags WHERE flag_status IN ('Open','UnderReview') ORDER BY risk_score DESC,created_at DESC","SELECT approval_id,from_account_id,to_account_id,amount,requested_at FROM Transaction_Approvals WHERE status='Requested' ORDER BY requested_at")
 foreach($profile in @('Baseline','Optimized')){
  if($profile -eq 'Optimized'){Db 'SOURCE indexes/01_performance_indexes.sql;' | Out-Null}
  Save-Text "$dir/$profile-indexes.txt" (@(Db "SELECT TABLE_NAME,INDEX_NAME,COLUMN_NAME FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() ORDER BY 1,2,SEQ_IN_INDEX;") -join "`n")
  for($q=0;$q -lt $queries.Count;$q++){
   Save-Text "$dir/$profile-plan-$q.txt" (@(Db "EXPLAIN $($queries[$q]);") -join "`n")
   for($i=0;$i -lt 22;$i++){
    $out=Db "SET @demo_start=NOW(6);$($queries[$q]);SELECT CONCAT('US|',TIMESTAMPDIFF(MICROSECOND,@demo_start,NOW(6)));"
    $us=[int64](($out|Where-Object {$_ -like 'US|*'}) -replace '^US\|','')
    if($i -ge 2){$measure.Add([pscustomobject]@{Profile=$profile;Query=$q;Sample=$i-1;Microseconds=$us})}
   }
  }
 }
 $measure|Export-Csv "$dir/performance.csv" -NoTypeInformation -Encoding UTF8
 $summary=@($measure|Group-Object Profile,Query|ForEach-Object{[pscustomobject]@{Group=$_.Name;Samples=$_.Count;MeanMicroseconds=[math]::Round(($_.Group|Measure-Object Microseconds -Average).Average,2);MinMicroseconds=($_.Group|Measure-Object Microseconds -Minimum).Minimum;MaxMicroseconds=($_.Group|Measure-Object Microseconds -Maximum).Maximum}})
 $summary|Export-Csv "$dir/performance-summary.csv" -NoTypeInformation -Encoding UTF8
 Check 'measured baseline optimized queries' ($measure.Count -eq 120) '3 fixed queries x20 measured samples x2 profiles; two warmups each; no speedup claim on tiny data'
 $inv=Db 'SOURCE tests/integration/04_after_experiments.sql;';Save-Text "$dir/final-invariants.txt" ($inv -join "`n")
 Check 'six final invariants' (@($inv -like 'TEST|PASS|*').Count -eq 6 -and @($inv -like 'TEST|FAIL|*').Count -eq 0) 'after CLI, fraud, isolation, real deadlock/retry and indexes'
}catch{if(!$fail){$fail++;Write-Output "TEST|FAIL|demo execution|$($_.Exception.Message)"};Save-Text "$dir/failure.txt" ($_.Exception.ToString()+"`n"+$_.ScriptStackTrace)}
finally{
 if($transferProbe -and $state){try{Db "DROP PROCEDURE IF EXISTS sp_internal_post_transfer;`n$originalTransfer" | Out-Null}catch{$fail++;Write-Output 'TEST|FAIL|temporary mode3 probe restore|see server error'}}
 if(Test-Path $session){& powershell -NoProfile -File demo/start_demo.ps1 -Action Stop -SessionFile $session;if($LASTEXITCODE){$fail++}}
 foreach($key in $saved.Keys){[Environment]::SetEnvironmentVariable($key,$saved[$key])}
 Save-Text "$dir/summary.txt" "TOTAL|PASS=$pass|FAIL=$fail`nDatabase=$($state.Database)`nNo restricted-role certification; no global settings changed."
 Write-Output "TOTAL|PASS=$pass|FAIL=$fail";Write-Output "EVIDENCE|$dir";Pop-Location
}
if($fail){exit 1}
