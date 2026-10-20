param([string]$SessionFile='demo/out/dashboard-session.json',[int]$Port=5000)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$python=$env:BANK_PYTHON_BIN
if(!$python){$c=Get-Command python -CommandType Application -ErrorAction SilentlyContinue;if($c){$python=$c.Source}else{throw 'Set BANK_PYTHON_BIN to Python3.10+; no additional packages required'}}
Push-Location $root
try{
 $state=Get-Content -LiteralPath $SessionFile -Raw | ConvertFrom-Json
 if($state.Status -cne 'ready' -or $state.Prefix -cnotmatch '^bank_a_ci_demo_[a-f0-9]{12}$' -or $state.Database -cne "$($state.Prefix)_main"){throw 'Refusing cleaned/invalid demo session'}
 $env:PYTHONUTF8='1'
 & $python demo/dashboard.py --session ([IO.Path]::GetFullPath($SessionFile)) --port $Port
 if($LASTEXITCODE){throw 'Dashboard exited with an error; database remains owned for explicit Stop'}
}finally{Pop-Location}
