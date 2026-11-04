param([switch]$Execute,[string]$StateFile='backup/out/durability_state.json',[int]$MysqldPid=0,[string]$ServiceName)
. "$PSScriptRoot/../../backup/ps/Common.ps1"
$s=Read-RecoveryState $StateFile
Assert-Scratch $s.Database
$services=@(Get-Service '*mysql*' -ErrorAction SilentlyContinue)
$servers=@(Get-Process mysqld -ErrorAction SilentlyContinue)
if(!$MysqldPid -and $servers.Count -eq 1){$MysqldPid=$servers[0].Id}
if(!$ServiceName -and $services.Count -eq 1){$ServiceName=$services[0].Name}
if(!$MysqldPid -or !$ServiceName){
 $text="DRY-RUN ONLY: no command executed.`nNEEDS MANUAL VERIFICATION: service detection returned $($services.Count) matches ($($services.Name -join ', ')); mysqld PID candidates: $(($servers.Id) -join ', ').`nPending PID verification: taskkill /F /PID <verified server PID>`nPending verification: Start-Service -Name '$ServiceName'`nResolve the target instance in an elevated shell; rerun with -MysqldPid <verified server PID> -ServiceName <verified Get-Service name>. No PID or service is guessed."
 Save-Text "$($s.Evidence)/crash-dry-run.txt" $text
 if($Execute){throw $text};Write-Output $text;return
}
if(!($servers | Where-Object Id -eq $MysqldPid)){throw 'Provided PID is not a current mysqld process.'}
$serverPid=$MysqldPid; $service=$ServiceName
$lines=@("DRY-RUN: taskkill /F /PID $serverPid","DRY-RUN: Start-Service -Name '$service'",'NEEDS MANUAL VERIFICATION: mysqld crash/restart has NOT been executed.')
if(!$Execute){Save-Text "$($s.Evidence)/crash-dry-run.txt" ($lines -join "`n");$lines;return}
$identity=[Security.Principal.WindowsIdentity]::GetCurrent()
$principal=[Security.Principal.WindowsPrincipal]::new($identity)
if(!$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw '-Execute requires an elevated interactive PowerShell.'}
if((Read-Host "Type CRASH MYSQL to terminate mysqld PID $serverPid and restart $service") -cne 'CRASH MYSQL'){throw 'Confirmation did not match.'}
if(!(Get-Service -Name $service -ErrorAction Stop)){throw 'Verified service is unavailable.'}
$ready=@(Invoke-BankMysql -Sql "SELECT COUNT(*) FROM information_schema.PROCESSLIST WHERE ID=$($s.ConnectionId) AND DB='bank_txn_scratch' AND INFO LIKE '%SLEEP(600)%';")[0]
if($ready -ne '1'){throw 'Uncommitted fixture expired; rerun setup before crash.'}
# Manual operator only: this deliberately crashes the whole server, not just scratch.
$start=Get-Date
& taskkill /F /PID $serverPid
if($LASTEXITCODE){throw 'taskkill failed.'}
Start-Service -Name $service
$connected=$false
for($i=0;$i -lt 60;$i++) {
 try {Invoke-BankMysql -Sql 'SELECT VERSION(),NOW(6);' | Out-Null;$connected=$true;break} catch {Start-Sleep -Seconds 1}
}
if(!$connected){throw 'MySQL failed to reconnect within 60 seconds.'}
$s.RecoveryExecuted=$true
Save-RecoveryState $s $StateFile
Save-Text "$($s.Evidence)/restart.txt" "process_crash_started=$($start.ToString('o'))`nreconnected=$((Get-Date).ToString('o'))`nservice=$service`nserver_pid=$serverPid"
& powershell -NoProfile -File experiments/EXP-03_durability/verify.ps1 -StateFile $StateFile
if($LASTEXITCODE){throw 'Post-crash verification failed.'}
