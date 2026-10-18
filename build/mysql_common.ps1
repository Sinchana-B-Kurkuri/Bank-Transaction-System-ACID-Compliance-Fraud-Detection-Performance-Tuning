$ErrorActionPreference = 'Stop'
function Assert-BankDatabase([string]$Database) {
 if ($Database -notin @('bank_txn','bank_txn_scratch')) { throw 'Database must be bank_txn or bank_txn_scratch.' }
}

function ConvertTo-BankNativeArgument([AllowEmptyString()][string]$Value) {
 # Windows CommandLineToArgvW rules, independent of PowerShell's native argument mode.
 # Quote every argument; double backslashes preceding quotes or the closing quote.
 return '"' + [regex]::Replace([regex]::Replace($Value, '(\\*)"', '$1$1\"'), '(\\+)$', '$1$1') + '"'
}

function Expand-BankSqlSource {
 param([string]$Sql, [string[]]$IncludeStack=@())
 $lines=foreach ($line in [regex]::Split($Sql, '\r?\n')) {
  if ($line -match '^\s*(?:SOURCE|\\\.)\s+(.+?)\s*;?\s*$') {
   $include=$Matches[1].Trim().TrimEnd(';').Trim()
   # mysql SOURCE paths are relative to the client working directory, not the including file.
   if ($include.Length -ge 2 -and (($include.StartsWith('"') -and $include.EndsWith('"')) -or ($include.StartsWith("'") -and $include.EndsWith("'")))) {
    $include=$include.Substring(1,$include.Length-2)
   }
   $path=(Resolve-Path -LiteralPath $include -ErrorAction Stop).ProviderPath
   if ($IncludeStack -contains $path) { throw "Recursive SQL SOURCE include: $include" }
   $contents=[IO.File]::ReadAllText($path,[Text.Encoding]::UTF8)
   "-- Included from $include"
   Expand-BankSqlSource -Sql $contents -IncludeStack ($IncludeStack + $path)
  } else { $line }
 }
 return $lines -join "`n"
}

function Invoke-BankMysql {
 param([string]$Database, [Parameter(Mandatory)][string]$Sql)
 if ($Database) { Assert-BankDatabase $Database }
 if (!$env:BANK_MYSQL_CNF) { throw 'BANK_MYSQL_CNF is unset; configure a local MySQL option file (never commit credentials).' }
 if (!(Test-Path -LiteralPath $env:BANK_MYSQL_CNF -PathType Leaf)) { throw 'BANK_MYSQL_CNF does not name an existing file.' }
 $optionFile=(Resolve-Path -LiteralPath $env:BANK_MYSQL_CNF).ProviderPath
 
$client = $null
foreach ($name in @('mysql', 'mysql.exe')) {
    $client = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($client) { break }
}

$clientPath = if ($env:BANK_MYSQL_BIN) {
    (Resolve-Path -LiteralPath $env:BANK_MYSQL_BIN -ErrorAction Stop).ProviderPath
} elseif ($client) {
    $client.Source
} else {
    $null
}

if (!$clientPath -and $IsWindows -and $env:ProgramFiles) {
    $candidates = @(
        Get-ChildItem -Path (Join-Path $env:ProgramFiles 'MySQL/MySQL Server */bin/mysql.exe') `
            -File -ErrorAction SilentlyContinue
    )
    if ($candidates.Count -eq 1) {
        $clientPath = $candidates[0].FullName
    }
}

if (!$clientPath) {
    throw 'MySQL client not found. Add mysql (macOS) or mysql.exe (Windows) to PATH, or set BANK_MYSQL_BIN.'
}

 # --abort-source-on-error is NOT an Oracle mysql option (8.4.11 exits 2).
 # Expand includes and feed stdin: batch mode without --force stops on the first SQL error.
 $inputSql=Expand-BankSqlSource -Sql $Sql
 $arguments=@("--defaults-extra-file=$optionFile",'--batch','--raw','--skip-column-names','--default-character-set=utf8mb4','--skip-force')
 if ($Database) { $arguments += "--database=$Database" }
 $start=[Diagnostics.ProcessStartInfo]::new()
 $start.FileName=$clientPath
 $start.Arguments=($arguments | ForEach-Object { ConvertTo-BankNativeArgument $_ }) -join ' '
 $start.WorkingDirectory=(Get-Location).ProviderPath
 $start.UseShellExecute=$false
 $start.CreateNoWindow=$true
 $start.RedirectStandardInput=$true
 $start.RedirectStandardOutput=$true
 $start.RedirectStandardError=$true
 $utf8=[Text.UTF8Encoding]::new($false)
 $start.StandardOutputEncoding=$utf8
 $start.StandardErrorEncoding=$utf8
 $process=[Diagnostics.Process]::new()
 $process.StartInfo=$start
 try {
  [void]$process.Start()
  # Drain both pipes concurrently, including when MySQL exits before reading stdin.
  $stdoutTask=$process.StandardOutput.ReadToEndAsync()
  $stderrTask=$process.StandardError.ReadToEndAsync()
  $writeFailure=$null
  # .NET Framework (Windows PowerShell 5.1) has no StandardInputEncoding property.
  # Write UTF-8 bytes directly so neither console encoding nor a BOM changes SQL.
  try {
   $inputBytes=$utf8.GetBytes($inputSql + "`n")
   $process.StandardInput.BaseStream.Write($inputBytes,0,$inputBytes.Length)
  }
  catch { $writeFailure=$_.Exception }
  finally { $process.StandardInput.BaseStream.Close() }
  $process.WaitForExit()
  $stdout=$stdoutTask.GetAwaiter().GetResult()
  $stderr=$stderrTask.GetAwaiter().GetResult()
  $code=$process.ExitCode
  if ($code -ne 0 -or $writeFailure) {
   $message="mysql exited $code"
   if ($stderr) { $message += ":`n$($stderr.TrimEnd())" }
   if ($writeFailure) { $message += "`nstdin write failed: $($writeFailure.Message)" }
   $failure=[Exception]::new($message)
   $failure.Data['ExitCode']=$code
   $failure.Data['StdOut']=$stdout
   $failure.Data['StdErr']=$stderr
   $failure.Data['RawOutput']="STDOUT:`n$stdout`nSTDERR:`n$stderr"
   throw $failure
  }
  # Warnings must remain visible without being parsed as SQL test result rows.
  if ($stderr) { [Console]::Error.Write($stderr) }
  if ($stdout) { [regex]::Split($stdout.TrimEnd("`r","`n"),'\r?\n') | Write-Output }
 } finally { $process.Dispose() }
}
