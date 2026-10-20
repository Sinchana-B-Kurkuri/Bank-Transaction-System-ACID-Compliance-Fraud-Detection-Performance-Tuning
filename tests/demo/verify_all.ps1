param([string]$Python=$env:BANK_PYTHON_BIN)
# Only the audited SQL/vetted-child runners. No reserved/global account tests.
$ErrorActionPreference='Stop'
$root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if(!$Python){$c=Get-Command python -CommandType Application -ErrorAction SilentlyContinue;if($c){$Python=$c.Source}else{throw 'Set BANK_PYTHON_BIN to Python3.10+'}}
$directory=Join-Path $root ('evidence/reviews/final-demo/runs/verify-'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff')+'-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($directory)
$failed=0
Push-Location $root
try{
 $ErrorActionPreference='Continue'
 $out=@(& $Python -m unittest discover -s tests/demo -p 'test_*.py' 2>&1|ForEach-Object{"$_"});$code=$LASTEXITCODE
 $ErrorActionPreference='Stop';$out|Set-Content "$directory/unit.txt" -Encoding UTF8
 if($code){$failed++;throw 'CLI input tests failed'}
 Write-Output 'TEST|PASS|CLI input unit suite|see unit.txt'
 foreach($file in @('tests/demo/run_safe_regression.ps1','tests/regression/pr9_acceptance.ps1','tests/regression/error1222_seed.ps1','tests/demo/run_demo.ps1')){
  $extra=if($file -eq 'tests/demo/run_demo.ps1'){@('-Python',$Python)}else{@()}
  $ErrorActionPreference='Continue'
  $out=@(& powershell -NoProfile -File $file @extra 2>&1|ForEach-Object{"$_"});$code=$LASTEXITCODE
  $ErrorActionPreference='Stop';$name=[IO.Path]::GetFileNameWithoutExtension($file)
  $out|Set-Content "$directory/$name.txt" -Encoding UTF8
  if($code){$failed++;Write-Output "TEST|FAIL|$file|exit=$code; see $name.txt"}else{Write-Output "TEST|PASS|$file|native exit0; raw nested counts retained"}
 }
}finally{Pop-Location;Write-Output "VERIFY|failed stages=$failed|evidence=$directory"}
if($failed){exit 1}
