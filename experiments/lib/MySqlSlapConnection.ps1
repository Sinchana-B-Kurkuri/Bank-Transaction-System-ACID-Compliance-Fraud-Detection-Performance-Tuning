# LAB ONLY — never ship
# mysqlslap does not accept every [client] option accepted by mysql.exe.
# Resolve native option-file settings in memory; never log or persist helper output.
function Get-MySqlSlapConnection {
 $printer=Join-Path (Split-Path (Get-MySqlPath) -Parent) my_print_defaults.exe
 $pi=[Diagnostics.ProcessStartInfo]::new()
 $pi.FileName=$printer
 $pi.Arguments=(@("--defaults-extra-file=$env:BANK_MYSQL_CNF",'--show','client','mysqlslap') | ForEach-Object { ConvertTo-BankNativeArgument $_ }) -join ' '
 $pi.UseShellExecute=$false; $pi.CreateNoWindow=$true; $pi.RedirectStandardOutput=$true; $pi.RedirectStandardError=$true
 $p=[Diagnostics.Process]::Start($pi)
 try {
  $output=$p.StandardOutput.ReadToEndAsync(); $errorOutput=$p.StandardError.ReadToEndAsync()
  $p.WaitForExit()
  if ($p.ExitCode) { throw 'my_print_defaults failed; credential-bearing output was deliberately not logged.' }
  $options=@('--no-defaults'); $password=$null
  foreach ($line in [regex]::Split($output.Result,'\r?\n')) {
   if ($line -match '^--password=(.*)$') { $password=$Matches[1] }
   elseif ($line -match '^--(user|host|port|protocol|socket|ssl-mode|ssl-ca|ssl-cert|ssl-key|ssl-cipher|connect-timeout|tls-version)=') { $options+=$line }
  }
  return [pscustomobject]@{Arguments=$options;Password=$password}
 } finally { $p.Dispose(); $output=$null; $errorOutput=$null }
}
