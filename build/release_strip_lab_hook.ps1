param()
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$output=Join-Path $PSScriptRoot 'release/procedures'
[void][IO.Directory]::CreateDirectory($output)
$guard="IF p_lab_mode <> 0 THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5017, MESSAGE_TEXT='E_LAB_MODE_FORBIDDEN: lab hook removed in release'; END IF;"
foreach ($name in @('sp_transfer_funds','sp_internal_post_transfer')) {
 $source=Join-Path $root "procedures/$name.sql"
 $sql=[IO.File]::ReadAllText($source)
 if ([regex]::Matches($sql,'-- RELEASE_GUARD_PLACEHOLDER').Count -ne 1) {throw "Expected one release guard marker in $name"}
 foreach ($region in @('LAB_HOOK','LAB_NAIVE')) {
  $begins=[regex]::Matches($sql,"-- ${region}_BEGIN").Count
  $ends=[regex]::Matches($sql,"-- ${region}_END").Count
  if ($begins -ne $ends) {throw "Unbalanced $region markers in $name"}
  $sql=[regex]::Replace($sql,"(?ms)^\s*-- ${region}_BEGIN.*?^\s*-- ${region}_END[^\r\n]*\r?\n",'')
 }
 $sql=$sql.Replace('-- RELEASE_GUARD_PLACEHOLDER',$guard)
 $sql=$sql.Replace(' OR p_lab_mode NOT IN (0,1,2,3)','').Replace(' DECLARE v_sleep INT;','')
 if ($sql -match '(?i)LAB_HOOK|SLEEP|@lab_sleep_seconds|p_lab_mode\s*=\s*[123]|p_lab_mode\s+IN\s*\([^)]*[123]') {throw "Lab logic remains in $name"}
 $originalSignature=[regex]::Match([IO.File]::ReadAllText($source),'(?s)CREATE PROCEDURE.*?SQL SECURITY DEFINER').Value
 if ([regex]::Match($sql,'(?s)CREATE PROCEDURE.*?SQL SECURITY DEFINER').Value -cne $originalSignature) {throw "Signature changed in $name"}
 $destination=Join-Path $output "$name.sql"
 [IO.File]::WriteAllText($destination,$sql,[Text.UTF8Encoding]::new($false))
 Write-Output "RELEASE|$name|signature retained; guard added; lab regions removed"
 & git diff --no-index --stat -- $source $destination
 if ($LASTEXITCODE -gt 1) {throw 'Could not compute release diff stats'}
}
exit 0
