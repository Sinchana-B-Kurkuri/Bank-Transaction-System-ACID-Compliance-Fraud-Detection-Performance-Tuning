param()
. "$PSScriptRoot/mysql_common.ps1"
$root = Split-Path $PSScriptRoot -Parent
$destination = Join-Path $root 'evidence/EV-ENV-1.txt'
$pushed=$false
try {
 [void][IO.Directory]::CreateDirectory((Split-Path $destination -Parent))
 Push-Location $root
 $pushed=$true
 $output = @(Invoke-BankMysql -Sql 'source build/env_check.sql')
 $output | Set-Content $destination -Encoding UTF8
 $output | Write-Output
 $record = "# Environment`n`nLOCALLY TESTED - measured on $(Get-Date -Format yyyy-MM-dd)`n`n``````text`n$($output -join "`n")`n```````n"
 $record | Set-Content (Join-Path $root 'docs/member-a/environment.md') -Encoding UTF8
} catch {
 $failure=$_
 $record=@("BLOCKED - $(Get-Date -Format yyyy-MM-dd): $($failure.Exception.Message)")
 if ($failure.Exception.Data.Contains('ExitCode')) { $record += "Exit code: $($failure.Exception.Data['ExitCode'])" }
 if ($failure.Exception.Data.Contains('RawOutput')) { $record += [string]$failure.Exception.Data['RawOutput'] }
 $record | Set-Content $destination -Encoding UTF8
 [Console]::Error.WriteLine(($record -join "`n"))
 exit 1
} finally { if ($pushed) { Pop-Location } }
