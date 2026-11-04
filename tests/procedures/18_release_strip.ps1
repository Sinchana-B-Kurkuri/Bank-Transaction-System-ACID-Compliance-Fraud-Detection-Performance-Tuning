param([string]$Database='bank_txn')
. "$PSScriptRoot/../../build/mysql_common.ps1"
Assert-BankDatabase $Database
$scratchDatabase=Get-BankScratchDatabase
$root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$failed=$false
try {
 Push-Location $root
 $ErrorActionPreference='Continue'
 $strip=@(& powershell -NoProfile -File build/release_strip_lab_hook.ps1 2>&1 | ForEach-Object {"$_"})
 $stripExit=$LASTEXITCODE
 $ErrorActionPreference='Stop'
 if ($stripExit -ne 0) {throw 'Release strip failed'}
 $strip | Set-Content (Get-BankEvidencePath 'evidence/EV-P3-RELEASE-1.txt') -Encoding UTF8
 & powershell -NoProfile -File build/rebuild.ps1 -Database $scratchDatabase -Mode Standalone -WithSeed | Out-Null
 if ($LASTEXITCODE -ne 0) {throw 'Scratch rebuild failed'}
 Invoke-BankMysql -Database $scratchDatabase -Sql "DROP PROCEDURE sp_transfer_funds; DROP PROCEDURE sp_internal_post_transfer;`nsource build/release/procedures/sp_internal_post_transfer.sql`nsource build/release/procedures/sp_transfer_funds.sql" | Out-Null
 $checks=@(Invoke-BankMysql -Database $scratchDatabase -Sql "SET @a=(SELECT account_id FROM Accounts WHERE account_number='SEED-0001'); SET @b=(SELECT account_id FROM Accounts WHERE account_number='SEED-0002'); SET @n=(SELECT COUNT(*) FROM Transactions); CALL bank_lab.sp_expect_error(DATABASE(),'released public rejects mode 1','CALL {db}.sp_transfer_funds(@a,@b,1,''Online'',NULL,NULL,NULL,1,@g,@d,@c)',5017); CALL bank_lab.sp_expect_error(DATABASE(),'released private rejects mode 1','CALL {db}.sp_internal_post_transfer(@a,@b,1,''Online'',NULL,NULL,NULL,1,0,@g,@d,@c)',5017); SET @ok=(SELECT COUNT(*)=@n FROM Transactions); CALL bank_lab.sp_assert_true(DATABASE(),'release rejection leaves no Failed rows',@ok,'No ledger rows added by 5017'); CALL bank_lab.sp_expect_ok(DATABASE(),'released ordered transfer works','CALL {db}.sp_transfer_funds(@a,@b,1,''Online'',NULL,NULL,NULL,0,@g,@d,@c)'); CALL sp_reconcile_balances(NULL); SELECT CONCAT('TEST|',IF(SUM(j.status='FAIL')=0,'PASS','FAIL'),'|released invariants|Six summaries checked') FROM JSON_TABLE(@reconcile_results,'`$[*]' COLUMNS(status VARCHAR(4) PATH '`$.status')) j;")
 $checks | Add-Content (Get-BankEvidencePath 'evidence/EV-P3-RELEASE-1.txt') -Encoding UTF8
 $checks | Where-Object {$_ -match '^TEST\|'} | Write-Output
 if ($checks -match '^TEST\|FAIL\|') {$failed=$true}
} catch {
 $failed=$true
 Write-Output "TEST|FAIL|release verification|$($_.Exception.Message)"
} finally {
 & powershell -NoProfile -File build/rebuild.ps1 -Database $scratchDatabase -Mode Standalone -WithSeed | Out-Null
 if ($LASTEXITCODE -ne 0) {$failed=$true; Write-Output 'TEST|FAIL|release scratch restore|Rebuild failed'}
 else {Write-Output 'TEST|PASS|release scratch restore|Development objects restored in scratch'}
 Pop-Location
}
if ($failed) {exit 1}
