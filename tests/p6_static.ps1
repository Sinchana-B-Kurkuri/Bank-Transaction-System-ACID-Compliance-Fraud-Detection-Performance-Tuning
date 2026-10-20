param([string]$Database='bank_txn',[string]$Snapshot='evidence/EV-B0-1.txt')
. "$PSScriptRoot/../build/mysql_common.ps1"
$root=Split-Path $PSScriptRoot -Parent;Set-Location $root
$failures=0
function Check-Static($Name,[bool]$Ok,$Detail) {
 Write-Output "TEST|$(if($Ok){'PASS'}else{'FAIL'})|$Name|$Detail"
 if(!$Ok){$script:failures++}
}
$order=@(Get-Content build/file_order.txt | Where-Object {$_ -notmatch '^#' -and $_.Trim()} | ForEach-Object {($_ -split '\|')[0].Trim()})
foreach($file in Get-ChildItem build/run_all*.sql) {
 $last=-1;$good=$true;$count=0
 foreach($line in Get-Content $file.FullName) {
  if($line -match '^\s*SOURCE\s+([^;]+);?\s*$'){
   $p=$Matches[1].Trim();$index=[array]::IndexOf($order,$p);$count++
   if($index -le $last -or !(Test-Path -LiteralPath $p)){$good=$false};$last=$index
  }
 }
 Check-Static "$($file.Name) source inventory" $good "$count existing, ordered SOURCE targets"
}
$bad=@();foreach($file in Get-ChildItem triggers/audit/*.sql){
 $body=[IO.File]::ReadAllText($file.FullName)
 $body=[regex]::Replace($body,'(?s)/\*.*?\*/|(?m)--[^\r\n]*','')
 if($body -match '(?i)\bCURRENT_USER\s*\('){$bad+=$file.Name}
}
Check-Static 'audit source session identity' ($bad.Count -eq 0) 'No CURRENT_USER() in installed A audit bodies'
$n=@(Invoke-BankMysql -Database $Database -Sql "SELECT COUNT(*) FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA=DATABASE() AND TRIGGER_NAME LIKE '%\\_audit' AND ACTION_STATEMENT REGEXP 'CURRENT_USER[[:space:]]*[(]';")[0]
Check-Static 'audit installed session identity' ($n -eq '0') 'Installed trigger bodies checked'
$release=@(Get-ChildItem build/release -Recurse -Filter *.sql -ErrorAction SilentlyContinue)
$bad=@($release | Where-Object {[IO.File]::ReadAllText($_.FullName) -match 'LAB_HOOK|@lab_sleep_seconds|\bSLEEP\s*\('})
Check-Static 'release lab regions absent' ($release.Count -ge 2 -and !$bad.Count) 'Generated release SQL examined, not development sources'
$n=@(Invoke-BankMysql -Database $Database -Sql "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME IN ('Card','CustomerAccount','TransactionType','TransactionLog','FraudAlert');")[0]
Check-Static 'obsolete tables absent' ($n -eq '0') 'Final schema only'
$core=@('Branches','Employees','Customers','Account_Types','Accounts','Transactions','Loans','Fraud_Flags','Audit_Log')
$list=($core | ForEach-Object {"'$_'"}) -join ','
$rows=@(Invoke-BankMysql -Database $Database -Sql "SELECT TABLE_SCHEMA,TABLE_NAME,INDEX_NAME,NON_UNIQUE,SEQ_IN_INDEX,COLUMN_NAME,INDEX_TYPE FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME IN ($list) ORDER BY TABLE_NAME,INDEX_NAME,SEQ_IN_INDEX;")
$actual=@($rows | ForEach-Object {($_ -split "`t" | Select-Object -Skip 1) -join "`t"} | Sort-Object)
$baseline=@(Get-Content -LiteralPath $Snapshot | Where-Object {$v=$_ -split "`t";$v.Count -eq 7 -and $core -contains $v[1]} | ForEach-Object {($_ -split "`t" | Select-Object -Skip 1) -join "`t"} | Sort-Object)
$diff=@(Compare-Object $baseline $actual)
Check-Static 'core B0 snapshot unchanged' (!$diff.Count -and $baseline.Count -gt 0) "Compared $($actual.Count) index-column records to $Snapshot"
$fk=@(Invoke-BankMysql -Database $Database -Sql "SELECT CONCAT(TABLE_NAME,'.',COLUMN_NAME) FROM information_schema.KEY_COLUMN_USAGE WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME IN ($list) AND REFERENCED_TABLE_NAME IS NOT NULL;")
$secondary=@($rows | Where-Object {($_ -split "`t")[3] -eq '1'})
$bad=@($secondary | Where-Object {$v=$_ -split "`t";$v[4] -ne '1' -or $fk -notcontains ($v[1]+'.'+$v[5])})
$duplicate=@($secondary | Group-Object { $v=$_ -split "`t";$v[1]+'.'+$v[5] } | Where-Object Count -gt 1)
Check-Static 'core secondary indexes FK-required only' (!$bad.Count -and !$duplicate.Count) 'Nonunique indexes must be one-column FK support with no duplicate support indexes'
$n=@(Invoke-BankMysql -Database $Database -Sql "SELECT COUNT(*) FROM mysql.procs_priv WHERE Db=DATABASE() AND Routine_type='PROCEDURE' AND Routine_name LIKE 'sp\\_internal\\_%' AND FIND_IN_SET('Execute',Proc_priv)>0;")[0]
Check-Static 'no direct private routine grants' ($n -eq '0') 'Does not certify absent B roles; administrative global privileges excluded'
& powershell -NoProfile -File tests/integration/support/Write-SignatureContract.ps1 -Check
if($LASTEXITCODE){$failures++}
if($failures){exit 1}
