param([string]$Database='bank_txn_scratch',[int]$Iterations=200,[int]$Parallel=20)
& "$PSScriptRoot/../lib/Run-Experiment.ps1" -Experiment '05' -Database $Database -Iterations $Iterations -Parallel $Parallel
