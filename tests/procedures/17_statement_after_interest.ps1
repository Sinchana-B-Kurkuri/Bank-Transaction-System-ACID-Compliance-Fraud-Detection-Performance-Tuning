param([string]$Database='bank_txn')
$ErrorActionPreference='Stop'
& powershell -NoProfile -File "$PSScriptRoot/14_statement_resultsets.ps1" -Database $Database |
 ForEach-Object { $_.Replace('statement actual running balances','statement after historical interest') }
exit $LASTEXITCODE
