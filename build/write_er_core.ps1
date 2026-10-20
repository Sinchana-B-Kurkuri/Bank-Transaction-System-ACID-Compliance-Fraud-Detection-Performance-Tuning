param([string]$Database='bank_txn')
. "$PSScriptRoot/mysql_common.ps1"
Assert-BankDatabase $Database
$root=Split-Path $PSScriptRoot -Parent
$names=@('Branches','Employees','Customers','Account_Types','Accounts','Transactions','Loans','Fraud_Flags','Audit_Log','Devices','Locations','Fraud_Rules','DB_User_Map','Transaction_Approvals','Fraud_Ground_Truth')
$canonical=@{};foreach($n in $names){$canonical[$n.ToLowerInvariant()]=$n}
$list=($names | ForEach-Object {"'$_'"}) -join ','
$cols=@(Invoke-BankMysql -Database $Database -Sql "SELECT TABLE_NAME,COLUMN_NAME,DATA_TYPE,COLUMN_TYPE,IS_NULLABLE,COLUMN_KEY FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME IN ($list) ORDER BY TABLE_NAME,ORDINAL_POSITION;")
$fks=@(Invoke-BankMysql -Database $Database -Sql "SELECT TABLE_NAME,COLUMN_NAME,REFERENCED_TABLE_NAME,REFERENCED_COLUMN_NAME FROM information_schema.KEY_COLUMN_USAGE WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME IN ($list) AND REFERENCED_TABLE_NAME IS NOT NULL ORDER BY TABLE_NAME,COLUMN_NAME;")
$lines=@('erDiagram','    %% Generated from real merged schema; A core + six B interfaces.','    %% Account_Risk_Profile is B-owned and outside this core/interface diagram.')
foreach($name in $names) {
 $lines+="    $name {"
 $found=@($cols | Where-Object {($_ -split "`t")[0] -eq $name})
 if(!$found.Count){throw "Missing table $name; build Integrated first."}
 foreach($line in $found) {
  $c=$line -split "`t";$keys=@()
  if($c[5] -eq 'PRI'){$keys+='PK'}elseif($c[5] -eq 'UNI'){$keys+='UK'}
  if(@($fks | Where-Object {$v=$_ -split "`t";$v[0] -eq $name -and $v[1] -eq $c[1]}).Count){$keys+='FK'}
  $key=if($keys.Count){' '+($keys -join ',')}else{''}
  $lines+="        $($c[2]) $($c[1])$key `"$($c[3].Replace('"','')); nullable=$($c[4])`""
 }
 $lines+='    }'
}
foreach($line in $fks) {
 $v=$line -split "`t";$child=$canonical[$v[0].ToLowerInvariant()];$parent=$canonical[$v[2].ToLowerInvariant()]
 $c=($cols | Where-Object {$x=$_ -split "`t";$x[0] -eq $child -and $x[1] -eq $v[1]} | Select-Object -First 1) -split "`t"
 $left=if($c[4] -eq 'YES'){'|o'}else{'||'};$right=if($c[5] -in @('PRI','UNI')){'o|'}else{'o{'}
 $lines+="    $parent $left--$right $child : $($v[1])"
 $lines+="    %% FK: $child.$($v[1]) -> $parent.$($v[3])"
}
[IO.File]::WriteAllText((Join-Path $root 'docs/er/er_core.mmd'),($lines -join "`n")+"`n",[Text.UTF8Encoding]::new($false))
Write-Output "ER|GENERATED|tables=$($names.Count)|FKs=$($fks.Count)|database=$Database"
