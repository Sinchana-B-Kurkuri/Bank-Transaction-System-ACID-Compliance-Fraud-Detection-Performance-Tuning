param([ValidateSet('Standalone','Integrated')][string]$Mode='Integrated',[string]$Database='bank_txn_scratch')
. "$PSScriptRoot/../build/mysql_common.ps1"
$root=Split-Path $PSScriptRoot -Parent
Set-Location $root
Assert-BankDatabase $Database
$log=[Collections.Generic.List[string]]::new();$pass=0;$fail=0
function Add-ReleaseOutput([string[]]$Lines) {
 $script:log.AddRange($Lines)
 foreach($line in $Lines | Where-Object {$_ -like 'TEST|*'}) {
  Write-Output $line
  if($line -like 'TEST|PASS|*'){$script:pass++}else{$script:fail++}
 }
}
try {
 $out=@(& powershell -NoProfile -File build/release_strip_lab_hook.ps1 2>&1 | ForEach-Object {"$_"});$log.AddRange([string[]]$out)
 if($LASTEXITCODE){throw 'Release generation failed.'}
 $out=@(& powershell -NoProfile -File build/rebuild.ps1 -Database $Database -Mode $Mode -WithSeed 2>&1 | ForEach-Object {"$_"});$log.AddRange([string[]]$out)
 if($LASTEXITCODE){throw 'Release scratch rebuild failed.'}
 Invoke-BankMysql -Database $Database -Sql "DROP PROCEDURE sp_transfer_funds; DROP PROCEDURE sp_internal_post_transfer;`nSOURCE build/release/procedures/sp_internal_post_transfer.sql;`nSOURCE build/release/procedures/sp_transfer_funds.sql;" | Out-Null
 foreach($file in Get-ChildItem tests/procedures -File | Where-Object {$_.Name -match '^\d\d_.*\.(sql|ps1)$'} | Sort-Object Name) {
  # These two harnesses rebuild scratch themselves: run in the development suite,
  # not inside a release suite where they would replace the objects under test.
  if($file.Name -in @('15_reconcile_scratch.ps1','18_release_strip.ps1')) {$log.Add("NOT_APPLICABLE|$($file.Name)|Already exercised by development regression; rebuilds the release target");continue}
  if($file.Extension -eq '.sql') {
   $sql=Expand-BankSqlSource -Sql "SOURCE tests/procedures/$($file.Name);"
   if($file.Name -eq '08_sp_transfer_funds.sql') {
    $sql=$sql.Replace("'transfer injected failure'","'release mode 1 forbidden'").Replace(',5016);',',5017);')
    $lines=foreach($line in $sql -split '\r?\n') {
     if($line -match "'transfer invalid lab mode'") {$line.Replace(',5018);',',5017);')}
     elseif($line -match "'transfer (lab sleep mode|naive lab direction)'") {$line.Replace('sp_expect_ok(','sp_expect_error(').Replace(")');",")',5017);")}
     else {$line}
    }
    $sql=$lines -join "`n"
    $log.Add('RELEASE_EXPECTATIONS|Only nonzero lab modes change to 5017; all business assertions retained. Development suite tests 5016/naive/sleep behavior separately.')
   }
   Add-ReleaseOutput @(Invoke-BankMysql -Database $Database -Sql $sql)
  } else {
   $out=@(& powershell -NoProfile -File $file.FullName -Database $Database 2>&1 | ForEach-Object {"$_"})
   Add-ReleaseOutput $out
   if($LASTEXITCODE){throw "$($file.Name) failed on release objects"}
  }
  $installed=@(Invoke-BankMysql -Database $Database -Sql "SELECT COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA=DATABASE() AND ROUTINE_NAME IN ('sp_transfer_funds','sp_internal_post_transfer') AND ROUTINE_DEFINITION LIKE '%E_LAB_MODE_FORBIDDEN%';")[0]
  if($installed -ne '2'){throw 'A test replaced release routines with development routines.'}
 }
 $guards=@'
SET @a=(SELECT account_id FROM Accounts WHERE account_number='SEED-0001');
SET @b=(SELECT account_id FROM Accounts WHERE account_number='SEED-0002');
CALL bank_lab.sp_expect_error(DATABASE(),'release mode negative forbidden','CALL {db}.sp_transfer_funds(@a,@b,1,''Online'',NULL,NULL,NULL,-1,@g,@d,@c)',5017);
CALL bank_lab.sp_expect_error(DATABASE(),'release internal mode forbidden','CALL {db}.sp_internal_post_transfer(@a,@b,1,''Online'',NULL,NULL,NULL,1,0,@g,@d,@c)',5017);
SOURCE tests/integration/06_signature_check.sql;
SOURCE tests/integration/04_after_experiments.sql;
'@
 Add-ReleaseOutput @(Invoke-BankMysql -Database $Database -Sql $guards)
} catch {$fail++;$log.Add("TEST|FAIL|release runner|$($_.Exception.Message)");Write-Output $log[-1]}
finally {
 $summary="TOTAL|RELEASE_PASS=$pass|FAIL=$fail";$log.Add($summary);Write-Output $summary
 $log | Set-Content (Get-BankEvidencePath 'evidence/EV-REL-1.txt') -Encoding UTF8
}
if($fail){exit 1}
