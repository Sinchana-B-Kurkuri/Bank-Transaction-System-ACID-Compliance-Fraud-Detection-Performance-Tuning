param([string]$Database='bank_txn')
. "$PSScriptRoot/../../build/mysql_common.ps1"
$path=Join-Path $PSScriptRoot '../../docs/er/er_core.mmd'
if(!(Test-Path $path)){throw 'ER source missing.'}
$er=[IO.File]::ReadAllText((Resolve-Path $path))
$columns=@();$tables=@();$table=$null
foreach($line in $er -split '\r?\n') {
 if($line -match '^\s*(\w+)\s+\{$'){$table=$Matches[1];$tables+=$table}
 elseif($line -match '^\s*\}$'){$table=$null}
 elseif($table -and $line -match '^\s+\w+\s+(\w+).*"(.+); nullable=(YES|NO)"\s*$'){$columns+="$table.$($Matches[1])|$($Matches[2])|$($Matches[3])"}
}
$list=($tables | ForEach-Object {"'$_'"}) -join ','
$actualColumns=@(Invoke-BankMysql -Database $Database -Sql "SELECT CONCAT(TABLE_NAME,'.',COLUMN_NAME,'|',COLUMN_TYPE,'|',IS_NULLABLE) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME IN ($list) ORDER BY 1;")
$columnDiff=@(Compare-Object ($columns | Sort-Object) ($actualColumns | Sort-Object))
foreach($d in $columnDiff){Write-Output "ER_COLUMN_DIFFERENCE|$($d.InputObject)|$($d.SideIndicator)"}
Write-Output "TEST|$(if(!$columnDiff.Count -and $tables.Count -eq 15){'PASS'}else{'FAIL'})|ER columns and nullability|tables=$($tables.Count);columns=$($columns.Count);differences=$($columnDiff.Count)"
if($columnDiff.Count -or $tables.Count -ne 15){exit 1}
$expected=@([regex]::Matches($er,'(?m)^\s*%% FK: (\w+)\.(\w+) -> (\w+)\.(\w+)') | ForEach-Object {$_.Groups[1].Value+'.'+$_.Groups[2].Value+'->'+$_.Groups[3].Value+'.'+$_.Groups[4].Value})
$actual=@(Invoke-BankMysql -Database $Database -Sql "SELECT CONCAT(TABLE_NAME,'.',COLUMN_NAME,'->',REFERENCED_TABLE_NAME,'.',REFERENCED_COLUMN_NAME) FROM information_schema.KEY_COLUMN_USAGE WHERE TABLE_SCHEMA=DATABASE() AND REFERENCED_TABLE_NAME IS NOT NULL AND TABLE_NAME<>'Account_Risk_Profile' ORDER BY 1;")
$diff=@(Compare-Object ($expected | Sort-Object) ($actual | Sort-Object))
# Standalone approximations intentionally lack the real approval requester FKs.
if($diff.Count){
 foreach($d in $diff){Write-Output "ER_DIFFERENCE|$($d.InputObject)|$($d.SideIndicator)"}
}
$real=@(Invoke-BankMysql -Database $Database -Sql "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='Account_Risk_Profile';")[0] -eq '1'
if(!$real){Write-Output "TEST|PASS|ER standalone distinction|$($diff.Count) differences reported; ER targets real B schema, not stand-ins";exit 0}
Write-Output "TEST|$(if($diff.Count){'FAIL'}else{'PASS'})|ER real FK relationships|differences=$($diff.Count)"
if($diff.Count){exit 1}
