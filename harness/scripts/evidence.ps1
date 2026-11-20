# GENESIS game harness — evidence runner.
#
# Runs tools/verify.ps1 unchanged, writes a timestamped report, and exits with
# the verification exit code. It never decides PASS on its own and never turns a
# missing engine into a green run.
#
# Usage (from the repository root):
#   pwsh -File harness/scripts/evidence.ps1 -Godot "<path to Godot 4.7.2>"
#   pwsh -File harness/scripts/evidence.ps1 -Godot "<path>" -SkipDemo

[CmdletBinding()]
param(
    [string]$Godot = "godot",
    [switch]$SkipDemo,
    [string]$OutDir = "",
    [string]$OutFile = ""
)

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$verify = Join-Path $root "tools/verify.ps1"
if (-not (Test-Path -LiteralPath $verify)) {
    Write-Host "Cannot find tools/verify.ps1 under $root" -ForegroundColor Red
    exit 1
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
if ($OutFile -eq "") {
    $reportDir = Join-Path $root ".superpowers/reports"
    New-Item -ItemType Directory -Force -Path $reportDir | Out-Null
    $OutFile = Join-Path $reportDir "verify-$timestamp.md"
}
else {
    $reportDir = Split-Path -Parent $OutFile
    if ($reportDir -ne "" -and -not (Test-Path -LiteralPath $reportDir)) {
        New-Item -ItemType Directory -Force -Path $reportDir | Out-Null
    }
}

$header = @(
    "# GENESIS verification report",
    "",
    ("- Timestamp: {0}" -f $timestamp),
    ("- Engine: ``{0}``" -f $Godot),
    ("- SkipDemo: {0}" -f $SkipDemo.IsPresent),
    ("- OutDir: {0}" -f $(if ($OutDir -eq "") { "(temp default)" } else { $OutDir })),
    "",
    "## tools/verify.ps1 output",
    "",
    '```text'
)
$header | Set-Content -LiteralPath $OutFile -Encoding utf8

$arguments = @("-NoProfile", "-File", $verify, "-Godot", $Godot)
if ($SkipDemo) { $arguments += "-SkipDemo" }
if ($OutDir -ne "") { $arguments += @("-OutDir", $OutDir) }

& pwsh @arguments 2>&1 | Tee-Object -FilePath $OutFile -Append | Out-Host
$code = $LASTEXITCODE

$footer = @('```', "", "## Result", "")
if ($code -eq 0) {
    $footer += "VERDICT: PASS — tools/verify.ps1 exited 0."
}
else {
    $footer += ("VERDICT: FAIL — VERIFY FAILED: tools/verify.ps1 exited {0}." -f $code)
}
$footer += @("", ("Report: ``{0}``" -f $OutFile))
$footer | Add-Content -LiteralPath $OutFile

Write-Host ""
Write-Host ("Report: {0}" -f $OutFile)
exit $code
