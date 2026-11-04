param([string]$Database='bank_txn_scratch',[int]$Iterations=50,[int]$Parallel=20)
& "$PSScriptRoot/../lib/Run-Experiment.ps1" -Experiment '09' -Database $Database -Iterations $Iterations -Parallel $Parallel
