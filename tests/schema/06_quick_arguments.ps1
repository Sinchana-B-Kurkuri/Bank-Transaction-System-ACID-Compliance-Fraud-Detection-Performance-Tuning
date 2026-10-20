param([string]$Database='bank_txn')
$ErrorActionPreference='Stop'
$fail=0
$path=Join-Path $PSScriptRoot '../../experiments/run_all_auto.ps1'
# All probes must fail before credentials, common library, evidence, or any workload.
foreach($arguments in @(@('-Quick','-SkipThroughput'),@('-Quick','-ResumeThroughput'),@('-Quik'))) {
 $ErrorActionPreference='Continue'
 $out=@(& powershell -NoProfile -File $path @arguments 2>&1 | ForEach-Object {"$_"})
 $code=$LASTEXITCODE
 $ErrorActionPreference='Stop'
 $ok=$code -ne 0 -and ($out -join ' ') -match 'exclusive bounded profile|Unknown experiment arguments' -and !($out -match '^RUNNING\|')
 if(!$ok){$fail++}
 Write-Output "TEST|$(if($ok){'PASS'}else{'FAIL'})|Quick invalid arguments $($arguments -join ' ')|Rejected before workload dispatch"
}
if($fail){exit 1}
