param([switch]$Check)
$ErrorActionPreference='Stop'
$root=Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
$signatures=[ordered]@{}
foreach($line in Get-Content "$root/docs/member-a/SPEC.md") {
 if($line -match '^sp_deposit / sp_withdraw\((.*)\)') {
  $signatures['sp_deposit']=$Matches[1];$signatures['sp_withdraw']=$Matches[1]
 } elseif($line -match '^(sp_\w+)\((.*)\)') {
  if($Matches[1] -ne 'sp_transfer_funds_retry'){$signatures[$Matches[1]]=$Matches[2]}
 }
}
$transfer=$signatures['sp_transfer_funds']
$in=[regex]::Matches($transfer,'\bIN\s+\w+\s+\w+(?:\([^)]*\))?') | ForEach-Object Value
$out=[regex]::Matches($transfer,'\bOUT\s+\w+\s+\w+(?:\([^)]*\))?') | ForEach-Object Value
$signatures['sp_transfer_funds_retry']=($in+@('IN p_max_retries INT')+$out+@('OUT p_attempts INT')) -join ', '
if($signatures.Count -ne 17){throw "Expected 17 SPEC public procedure contracts, found $($signatures.Count)."}
$rows=@()
foreach($name in $signatures.Keys) {
 $ordinal=0
 foreach($p in [regex]::Matches($signatures[$name],'\b(IN|OUT)\s+(\w+)\s+(\w+(?:\([^)]*\))?)')) {
  $ordinal++
  $rows+="('$name',$ordinal,'$($p.Groups[1].Value)','$($p.Groups[2].Value)','$($p.Groups[3].Value.ToLowerInvariant().Replace(' ',''))')"
 }
 if(!$ordinal){throw "No parsed parameters for $name"}
}
$sql=@'
-- Generated only from authoritative SPEC by support/Write-SignatureContract.ps1.
-- Deposit/withdraw and retry abbreviations are expanded, never inferred from installed routines.
CREATE TEMPORARY TABLE spec_parameters(proc_name VARCHAR(64),ordinal INT,mode_name VARCHAR(5),param_name VARCHAR(64),type_name VARCHAR(64));
INSERT INTO spec_parameters VALUES
'@ + "`n" + ($rows -join ",`n") + ";`n" + @'
SELECT CONCAT('TEST|',IF(SUM(p.PARAMETER_NAME IS NULL OR BINARY p.PARAMETER_NAME<>BINARY e.param_name OR p.PARAMETER_MODE<>e.mode_name OR LOWER(REPLACE(p.DTD_IDENTIFIER,' ',''))<>e.type_name)=0
 AND COUNT(*)=(SELECT COUNT(*) FROM information_schema.PARAMETERS x WHERE x.SPECIFIC_SCHEMA=DATABASE() AND x.SPECIFIC_NAME=e.proc_name AND x.ROUTINE_TYPE='PROCEDURE'),'PASS','FAIL'),
 '|SPEC signature ',e.proc_name,'|Expected exact name/mode/type/count; parameters=',COUNT(*))
FROM spec_parameters e LEFT JOIN information_schema.PARAMETERS p ON p.SPECIFIC_SCHEMA=DATABASE() AND p.SPECIFIC_NAME=e.proc_name AND p.ROUTINE_TYPE='PROCEDURE' AND p.ORDINAL_POSITION=e.ordinal
GROUP BY e.proc_name ORDER BY e.proc_name;
SELECT CONCAT('TEST|',IF(COUNT(r.ROUTINE_NAME)=1 AND MIN(r.SECURITY_TYPE)='DEFINER','PASS','FAIL'),'|public DEFINER ',e.proc_name,'|Routine exists and SQL SECURITY DEFINER')
FROM (SELECT DISTINCT proc_name FROM spec_parameters) e LEFT JOIN information_schema.ROUTINES r ON r.ROUTINE_SCHEMA=DATABASE() AND r.ROUTINE_NAME=e.proc_name AND r.ROUTINE_TYPE='PROCEDURE' GROUP BY e.proc_name ORDER BY e.proc_name;
DROP TEMPORARY TABLE spec_parameters;
'@
$path=Join-Path $root 'tests/integration/06_signature_check.sql'
if($Check) {
 if(!(Test-Path $path) -or [IO.File]::ReadAllText($path).Replace("`r`n","`n") -cne $sql.Replace("`r`n","`n")){throw 'Signature SQL differs from SPEC; regenerate with Write-SignatureContract.ps1.'}
 Write-Output 'TEST|PASS|SPEC signature fixture provenance|Generated expectations match current SPEC'
} else {[IO.File]::WriteAllText($path,$sql,[Text.UTF8Encoding]::new($false))}
