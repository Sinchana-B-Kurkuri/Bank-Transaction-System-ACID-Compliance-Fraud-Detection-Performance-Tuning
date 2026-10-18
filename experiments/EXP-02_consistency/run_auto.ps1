param([string]$Database='bank_txn_scratch')
. "$PSScriptRoot/../lib/Common.ps1"
Initialize-Lab $Database
$dir=New-EvidenceDir 'EXP-02'; $id=Get-Date -Format 'yyyyMMdd-HHmmss-fff'
$out=Invoke-MySql $Database -Sql "SET @test_run_id='EXP02-$id';`nSOURCE tests/integration/03_exp02.sql;" -OutputFile "$dir/tests.txt"
# SOURCE must occupy its own line for recursive fail-fast include expansion.
$rows=Invoke-MySql $Database -Sql "SELECT test_name,status,detail FROM bank_lab.Test_Results WHERE run_id='EXP02-$id' ORDER BY result_id;" -OutputFile "$dir/test-results.txt"
$text="# EXP-02 measured consistency attempts`n`n| Attempt | Status | Expected errno; actual errno/message |`n|---|---|---|`n"
foreach ($line in $rows) { $text+='| '+($line -replace "`t",' | ' -replace '\|(?=[^ ])','/')+" |`n" }
Save-Text evidence/EV-EXP02-1.md ($text+"`nRaw: $dir")
if (@($out | Where-Object { $_ -match '^TEST\|FAIL' }).Count) { throw 'EXP02 failed.' }
Complete-Experiment $PSScriptRoot $dir @("RESULT|EXP-02|ALL|passed|$(@($out | Where-Object { $_ -match '^TEST\|PASS' }).Count)")
