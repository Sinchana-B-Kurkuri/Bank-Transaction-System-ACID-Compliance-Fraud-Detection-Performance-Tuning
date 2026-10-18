param([string]$Database='bank_txn')
$ErrorActionPreference='Stop'
. "$PSScriptRoot/../../build/mysql_common.ps1"
# Isolated process probe, NOT a MySQL substitute for database tests. It checks the
# Windows PowerShell/.NET argument boundary and stderr handling without credentials.
$directory=Join-Path ([IO.Path]::GetTempPath()) ('bank wrapper probe ' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($directory)
$savedPath=$env:PATH
$savedCnf=$env:BANK_MYSQL_CNF
$savedLocation=Get-Location
$failures=0
function Report-Probe([string]$Name,[bool]$Condition,[string]$Detail) {
 $status=if ($Condition) {'PASS'} else {'FAIL'}
 if (!$Condition) { $script:failures++ }
 Write-Output "TEST|$status|wrapper $Name|$Detail"
}
try {
 $source=@'
using System;
using System.IO;
using System.Text;
public class MysqlWrapperProbe {
 public static int Main(string[] args) {
  Console.InputEncoding = new UTF8Encoding(false);
  Console.OutputEncoding = new UTF8Encoding(false);
  if(args.Length < 6 || !args[0].StartsWith("--defaults-extra-file=")) return 81;
  string cnf = args[0].Substring("--defaults-extra-file=".Length);
  if(!File.Exists(cnf) || !cnf.Contains(" ")) return 82;
  foreach(string arg in args) {
   if(arg == "--abort-source-on-error" || arg == "-e") return 83;
  }
  string sql=Console.In.ReadToEnd();
  if(sql.Contains("PROBE_FAILURE")) {
   Console.WriteLine("partial stdout");
   Console.Error.WriteLine("probe stderr: exact diagnostic");
   return 2;
  }
  if(!sql.Contains("SELECT 'nested';") || !sql.Contains("DELIMITER $$") || !sql.Contains("quoted \\\" value")) return 84;
  Console.WriteLine("probe success");
  return 0;
 }
}
'@
 Add-Type -TypeDefinition $source -OutputAssembly (Join-Path $directory 'mysql.exe') -OutputType ConsoleApplication
 $env:PATH=$directory + [IO.Path]::PathSeparator + $savedPath
 $env:BANK_MYSQL_CNF=Join-Path $directory 'client settings.cnf'
 [IO.File]::WriteAllText($env:BANK_MYSQL_CNF,"[client]`n",[Text.UTF8Encoding]::new($false))
 Set-Location $directory
 [IO.File]::WriteAllText((Join-Path $directory 'nested file.sql'),"SELECT 'nested';`n",[Text.UTF8Encoding]::new($false))
 $sql='DELIMITER $$' + "`n" + 'SELECT ''quoted \" value'';' + "`nSOURCE nested file.sql;`n"
 $expanded=Expand-BankSqlSource $sql
 Report-Probe 'include expansion' ($expanded.Contains("SELECT 'nested';") -and !$expanded.Contains('SOURCE nested file.sql')) 'Nested include with spaces expanded before batch execution'
 $output=@(Invoke-BankMysql -Sql $sql)
 Report-Probe 'paths with spaces' ($output -contains 'probe success') 'Executable and first option-file argument survived Windows PowerShell quoting; SQL used stdin'
 try {
  Invoke-BankMysql -Sql 'PROBE_FAILURE'
  Report-Probe 'stderr and exit code' $false 'Expected process failure was not thrown'
 } catch {
  $exception=$_.Exception
  $ok=$exception.Data['ExitCode'] -eq 2 -and $exception.Data['StdOut'].Contains('partial stdout') -and $exception.Data['StdErr'].Contains('probe stderr: exact diagnostic') -and $exception.Message.Contains('probe stderr: exact diagnostic')
  Report-Probe 'stderr and exit code' $ok 'Exit 2, partial stdout and original stderr retained in exception data and message'
 }
 [IO.File]::WriteAllText((Join-Path $directory 'recursive.sql'),'SOURCE recursive.sql;')
 try {
  $ignored=Expand-BankSqlSource 'SOURCE recursive.sql;'
  Report-Probe 'recursive include guard' $false 'Expected recursive include rejection'
 } catch {
  Report-Probe 'recursive include guard' ($_.Exception.Message -like '*Recursive SQL SOURCE*') 'Rejected include cycle before starting a process'
 }
} catch {
 Report-Probe 'probe execution' $false $_.Exception.Message
} finally {
 Set-Location $savedLocation
 $env:PATH=$savedPath
 $env:BANK_MYSQL_CNF=$savedCnf
 # Only the exact temporary files created above are removed; no recursive deletion.
 foreach ($name in @('mysql.exe','client settings.cnf','nested file.sql','recursive.sql')) {
  $path=Join-Path $directory $name
  if ([IO.File]::Exists($path)) { [IO.File]::Delete($path) }
 }
 if ([IO.Directory]::GetFileSystemEntries($directory).Length -eq 0) { [IO.Directory]::Delete($directory) }
}
if ($failures) {exit 1}
exit 0
