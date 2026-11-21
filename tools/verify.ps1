# GENESIS — one-command verification for M0–M5 plus the region slice and map runner.
#
# Runs the import prerequisite, the headless smoke checks (M0/M1/M2/M5), the
# headless regression checks and the windowed demos (M1/M2/M3/M5), then reports
# a summary. Exits 0 only if every check passed. The demo checks require a real
# window (headless runs cannot capture screenshots) — pass -SkipDemo on a
# machine without a display.
#
# Demo screenshots go to a temp folder by default so verification does not
# dirty the tracked evidence in creative/muse/outputs/experiments/. Pass
# -OutDir "creative/muse/outputs/experiments" to deliberately regenerate it.
#
# Usage (from the repository root):
#   pwsh -File tools/verify.ps1 -Godot "C:\path\to\Godot_v4.7.2-stable_win64_console.exe"
#
# On Linux, the same checks are the commands in docs/MILESTONES.md.

[CmdletBinding()]
param(
    [string]$Godot = "godot",
    [string]$OutDir = "",
    [switch]$SkipDemo
)

$root = Split-Path -Parent $PSScriptRoot
Push-Location $root

# Preflight: a missing engine must not look like a green run.
$godotCmd = Get-Command $Godot -ErrorAction SilentlyContinue
if ($null -eq $godotCmd) {
    Pop-Location
    Write-Host "Cannot find the Godot executable: $Godot" -ForegroundColor Red
    Write-Host "Pass -Godot <path to Godot_v4.7.2-stable_win64_console.exe>" -ForegroundColor Red
    exit 1
}
$GodotExe = if ($godotCmd.Path) { $godotCmd.Path } else { $Godot }

$results = [System.Collections.Generic.List[object]]::new()

function Invoke-Check {
    param(
        [string]$Name,
        [string[]]$Arguments,
        [string]$ExpectPattern = ""
    )
    $output = ""
    $exit = 1
    try {
        $output = & $GodotExe @Arguments 2>&1 | Out-String
        $exit = $LASTEXITCODE
    }
    catch {
        $output = "invocation failed: $_"
    }
    $ok = ($exit -eq 0)
    if ($ok -and $ExpectPattern -ne "") {
        $ok = $output -match $ExpectPattern
    }
    $display = $Arguments -join " "
    Write-Host ("[{0}] {1}" -f ($(if ($ok) { "PASS" } else { "FAIL" })), $Name)
    $results.Add([pscustomobject]@{ Name = $Name; Passed = $ok; Exit = $exit; Command = "$GodotExe $display" })
    if (-not $ok) {
        Write-Host "      command: $GodotExe $display"
        Write-Host "      exit=$exit"
        ($output -split "`n" | Select-Object -Last 25) | ForEach-Object { Write-Host "      $_" }
    }
    return $ok
}

try {
    Invoke-Check "import project (fresh clone prerequisite)" @("--headless", "--path", "game", "--import") | Out-Null
    Invoke-Check "M0 smoke: test scene loads" @("--headless", "--audio-driver", "Dummy", "--path", "game", "res://scenes/test_scene.tscn", "--quit-after", "5") '\[M0\] READY' | Out-Null
    Invoke-Check "M1 smoke: movement scene loads" @("--headless", "--audio-driver", "Dummy", "--path", "game", "res://scenes/movement_test.tscn", "--quit-after", "5") '\[M1\] READY' | Out-Null
    Invoke-Check "M2 smoke: prototype scene loads" @("--headless", "--audio-driver", "Dummy", "--path", "game", "res://scenes/prototype.tscn", "--quit-after", "5") '\[M2\] READY' | Out-Null
    Invoke-Check "M5 smoke: boss arena loads" @("--headless", "--audio-driver", "Dummy", "--path", "game", "res://scenes/boss_test.tscn", "--quit-after", "5", "--", "--fresh-save") '\[M5\] READY' | Out-Null
    Invoke-Check "map03 smoke: stage scene loads" @("--headless", "--audio-driver", "Dummy", "--path", "game", "res://scenes/map03.tscn", "--quit-after", "5") '\[MAP03\] READY map03' | Out-Null
    Invoke-Check "map02 smoke: stage scene loads" @("--headless", "--audio-driver", "Dummy", "--path", "game", "res://scenes/map02.tscn", "--quit-after", "5") '\[MAP02\] READY map02' | Out-Null
    Invoke-Check "map04 smoke: stage scene loads" @("--headless", "--audio-driver", "Dummy", "--path", "game", "res://scenes/map04.tscn", "--quit-after", "5") '\[MAP04\] READY map04' | Out-Null
    Invoke-Check "map05 smoke: stage scene loads" @("--headless", "--audio-driver", "Dummy", "--path", "game", "res://scenes/map05.tscn", "--quit-after", "5") '\[MAP05\] READY map05' | Out-Null
    Invoke-Check "map06 smoke: stage scene loads" @("--headless", "--audio-driver", "Dummy", "--path", "game", "res://scenes/map06.tscn", "--quit-after", "5") '\[MAP06\] READY map06' | Out-Null
    Invoke-Check "map07 smoke: stage scene loads" @("--headless", "--audio-driver", "Dummy", "--path", "game", "res://scenes/map07.tscn", "--quit-after", "5") '\[MAP07\] READY map07' | Out-Null
    Invoke-Check "map08 smoke: stage scene loads" @("--headless", "--audio-driver", "Dummy", "--path", "game", "res://scenes/map08.tscn", "--quit-after", "5") '\[MAP08\] READY map08' | Out-Null
    Invoke-Check "regression: grip detach contract" @("--headless", "--audio-driver", "Dummy", "--path", "game", "--script", "res://tests/grip_detach_check.gd") 'ALL PASS' | Out-Null
    Invoke-Check "regression: demo verdict can fail" @("--headless", "--audio-driver", "Dummy", "--path", "game", "--script", "res://tests/demo_verdict_check.gd") 'ALL PASS' | Out-Null
    Invoke-Check "regression: absorption contract" @("--headless", "--audio-driver", "Dummy", "--path", "game", "--script", "res://tests/absorption_check.gd") 'ALL PASS' | Out-Null
    Invoke-Check "regression: survival contract" @("--headless", "--audio-driver", "Dummy", "--path", "game", "--script", "res://tests/survival_check.gd") 'ALL PASS' | Out-Null
    Invoke-Check "regression: M2 demo verdict can fail" @("--headless", "--audio-driver", "Dummy", "--path", "game", "--script", "res://tests/m2_verdict_check.gd") 'ALL PASS' | Out-Null
    Invoke-Check "regression: evolution contract" @("--headless", "--audio-driver", "Dummy", "--path", "game", "--script", "res://tests/evolution_check.gd") 'ALL PASS' | Out-Null
    Invoke-Check "regression: energy contract" @("--headless", "--audio-driver", "Dummy", "--path", "game", "--script", "res://tests/energy_check.gd") 'ALL PASS' | Out-Null
    Invoke-Check "regression: M3 demo verdict can fail" @("--headless", "--audio-driver", "Dummy", "--path", "game", "--script", "res://tests/m3_verdict_check.gd") 'ALL PASS' | Out-Null
    Invoke-Check "regression: boss state machine contract" @("--headless", "--audio-driver", "Dummy", "--path", "game", "--script", "res://tests/boss_check.gd") 'ALL PASS' | Out-Null
    Invoke-Check "regression: M5 demo verdict can fail" @("--headless", "--audio-driver", "Dummy", "--path", "game", "--script", "res://tests/m5_verdict_check.gd") 'ALL PASS' | Out-Null
    Invoke-Check "regression: region slice rules" @("--headless", "--audio-driver", "Dummy", "--path", "game", "--script", "res://tests/region_slice_check.gd") 'ALL PASS' | Out-Null
    Invoke-Check "regression: map runner rules" @("--headless", "--audio-driver", "Dummy", "--path", "game", "--script", "res://tests/map_runner_check.gd") 'ALL PASS' | Out-Null
    Invoke-Check "regression: map03 stage rules" @("--headless", "--audio-driver", "Dummy", "--path", "game", "--script", "res://tests/map03_check.gd") 'ALL PASS' | Out-Null
    Invoke-Check "regression: map02 stage rules" @("--headless", "--audio-driver", "Dummy", "--path", "game", "--script", "res://tests/map02_check.gd") 'ALL PASS' | Out-Null
    Invoke-Check "regression: map04 stage rules" @("--headless", "--audio-driver", "Dummy", "--path", "game", "--script", "res://tests/map04_check.gd") 'ALL PASS' | Out-Null
    Invoke-Check "regression: map05 stage rules" @("--headless", "--audio-driver", "Dummy", "--path", "game", "--script", "res://tests/map05_check.gd") 'ALL PASS' | Out-Null
    Invoke-Check "regression: map06 stage rules" @("--headless", "--audio-driver", "Dummy", "--path", "game", "--script", "res://tests/map06_check.gd") 'ALL PASS' | Out-Null
    Invoke-Check "regression: map07 stage rules" @("--headless", "--audio-driver", "Dummy", "--path", "game", "--script", "res://tests/map07_check.gd") 'ALL PASS' | Out-Null
    Invoke-Check "regression: map08 stage rules" @("--headless", "--audio-driver", "Dummy", "--path", "game", "--script", "res://tests/map08_check.gd") 'ALL PASS' | Out-Null

    if ($SkipDemo) {
        Write-Host "[SKIP] M1 demo autopilot (-SkipDemo)"
    } else {
        # Godot resolves relative paths against the project dir (game/), so the
        # outdir must be absolute or the screenshots fail to save.
        $outPath = $OutDir
        if ($outPath -eq "") {
            $outPath = Join-Path ([System.IO.Path]::GetTempPath()) "genesis-m1"
        }
        elseif (-not [System.IO.Path]::IsPathRooted($outPath)) {
            $outPath = Join-Path $root $outPath
        }
        New-Item -ItemType Directory -Force -Path $outPath | Out-Null
        $outPath = (Resolve-Path $outPath).Path
        Write-Host "      demo screenshots: $outPath"
        Invoke-Check "M1 demo autopilot (swim/crawl/grip/camera)" @("--audio-driver", "Dummy", "--path", "game", "res://scenes/movement_test.tscn", "--", "--m1-demo", "--outdir=$outPath") 'DEMO RESULT: PASS' | Out-Null
        Invoke-Check "M2 demo autopilot (absorb/hit/retry)" @("--audio-driver", "Dummy", "--path", "game", "res://scenes/prototype.tscn", "--", "--m2-demo", "--outdir=$outPath") 'DEMO RESULT: PASS' | Out-Null
        Invoke-Check "M3 demo autopilot (feed/evolve/kill)" @("--audio-driver", "Dummy", "--path", "game", "res://scenes/prototype.tscn", "--", "--m3-demo", "--outdir=$outPath") 'DEMO RESULT: PASS' | Out-Null
        Invoke-Check "M5 demo autopilot (evolve/telegraph/weak-window/victory)" @("--audio-driver", "Dummy", "--path", "game", "res://scenes/boss_test.tscn", "--", "--m5-demo", "--outdir=$outPath", "--fresh-save") 'DEMO RESULT: PASS' | Out-Null
        # Headless by design: this autopilot reports failures by name, never captures screenshots.
        Invoke-Check "map03 demo autopilot (feed/evolve/gate/boss/completion)" @("--headless", "--audio-driver", "Dummy", "--path", "game", "res://scenes/map03.tscn", "--", "--map03-demo") 'MAP03 RESULT: PASS' | Out-Null
        Invoke-Check "map02 demo autopilot (feed/evolve/slits/boss/completion)" @("--headless", "--audio-driver", "Dummy", "--path", "game", "res://scenes/map02.tscn", "--", "--map02-demo") 'MAP02 RESULT: PASS' | Out-Null
        Invoke-Check "map04 demo autopilot (feed/evolve/membranes/boss/completion)" @("--headless", "--audio-driver", "Dummy", "--path", "game", "res://scenes/map04.tscn", "--", "--map-demo=map04") 'MAP04 RESULT: PASS' | Out-Null
        Invoke-Check "map05 demo autopilot (feed/evolve/pillars/grip/boss/completion)" @("--headless", "--audio-driver", "Dummy", "--path", "game", "res://scenes/map05.tscn", "--", "--map-demo=map05") 'MAP05 RESULT: PASS' | Out-Null
        Invoke-Check "map06 demo autopilot (feed/evolve/platforms/grip/boss/completion)" @("--headless", "--audio-driver", "Dummy", "--path", "game", "res://scenes/map06.tscn", "--", "--map-demo=map06") 'MAP06 RESULT: PASS' | Out-Null
        Invoke-Check "map07 demo autopilot (feed/evolve/shaft/grip/boss/completion)" @("--headless", "--audio-driver", "Dummy", "--path", "game", "res://scenes/map07.tscn", "--", "--map-demo=map07") 'MAP07 RESULT: PASS' | Out-Null
        Invoke-Check "map08 demo autopilot (feed/evolve/constriction/gate/boss/completion)" @("--headless", "--audio-driver", "Dummy", "--path", "game", "res://scenes/map08.tscn", "--", "--map-demo=map08") 'MAP08 RESULT: PASS' | Out-Null
    }
}
finally {
    Pop-Location
}

Write-Host ""
Write-Host "Summary"
$results | Format-Table -AutoSize Name, Passed, Exit | Out-String | Write-Host
$failed = @($results | Where-Object { -not $_.Passed })
if ($results.Count -eq 0) {
    Write-Host "VERIFY FAILED: no checks ran" -ForegroundColor Red
    exit 1
}
if ($failed.Count -gt 0) {
    Write-Host ("VERIFY FAILED: {0} of {1} checks failed" -f $failed.Count, $results.Count) -ForegroundColor Red
    exit 1
}
Write-Host ("VERIFY PASSED: {0} checks" -f $results.Count) -ForegroundColor Green
exit 0
