param([string]$Database='bank_txn')
. "$PSScriptRoot/../../build/mysql_common.ps1"
$saved=@{};foreach($key in @('BANK_TEST_ISOLATED_PREFIX','BANK_TEST_OWNER_TOKEN','BANK_TEST_EVIDENCE_DIR')){$saved[$key]=[Environment]::GetEnvironmentVariable($key)}
$fail=0
function Context-Check($Name,[bool]$Ok) {
 Write-Output "TEST|$(if($Ok){'PASS'}else{'FAIL'})|isolated context $Name|No database statement executed by this safety test"
 if(!$Ok){$script:fail++}
}
function Context-Reject($Name,[scriptblock]$Action) {
 $rejected=$false;try {& $Action | Out-Null}catch{$rejected=$true}
 Context-Check $Name $rejected
}
try {
 $env:BANK_TEST_ISOLATED_PREFIX='bank_a_ci_safety_probe'
 $env:BANK_TEST_OWNER_TOKEN='0123456789abcdef0123456789abcdef'
 $env:BANK_TEST_EVIDENCE_DIR=Join-Path ([IO.Path]::GetTempPath()) 'bank-context-probe'
 Context-Check 'scratch propagation' ((Get-BankScratchDatabase) -ceq 'bank_a_ci_safety_probe_scratch')
 Context-Reject 'bank_txn target refused' {Assert-BankDatabase bank_txn}
 Context-Reject 'bank_txn_scratch target refused' {Assert-BankDatabase bank_txn_scratch}
 Context-Reject 'other isolated prefix refused' {Assert-BankDatabase bank_a_ci_other_main}
 Context-Reject 'hardcoded qualified SQL refused' {ConvertTo-BankContextSql 'SELECT * FROM bank_txn.Accounts;'}
 Context-Reject 'unapproved CREATE refused' {ConvertTo-BankContextSql 'CREATE DATABASE unrelated;'}
 Context-Reject 'unapproved DROP refused' {ConvertTo-BankContextSql 'DROP DATABASE unrelated;'}
 Context-Reject 'unapproved USE refused' {ConvertTo-BankContextSql 'USE unrelated;'}
 Context-Reject 'GLOBAL change refused' {ConvertTo-BankContextSql 'SET GLOBAL transaction_isolation=''READ-COMMITTED'';'}
 $sql=ConvertTo-BankContextSql 'CALL bank_lab.sp_assert_true(DATABASE(),''probe'',1,''ok'');'
 Context-Check 'helper namespace rewritten' ($sql -match 'bank_a_ci_safety_probe_lab\.sp_assert_true' -and $sql -notmatch '\bbank_lab\b')
 $env:BANK_TEST_ISOLATED_PREFIX='bank_txn'
 Context-Reject 'unsafe prefix refused' {Assert-BankIsolatedContext}
 $env:BANK_TEST_ISOLATED_PREFIX=$null
 Context-Check 'default scratch unchanged' ((Get-BankScratchDatabase) -ceq 'bank_txn_scratch')
 Assert-BankDatabase bank_txn;Assert-BankDatabase bank_txn_scratch
 Context-Check 'default banking targets unchanged' $true
 Context-Reject 'default arbitrary target refused' {Assert-BankDatabase unrelated}
} finally {foreach($key in $saved.Keys){[Environment]::SetEnvironmentVariable($key,$saved[$key])}}
if($fail){exit 1}
