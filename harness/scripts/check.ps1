# GENESIS game harness — structural check.
#
# Proves the harness is present and internally consistent. It does not run
# Godot and does not judge skill quality; evidence.ps1 owns the game checks.
#
# Usage (from the repository root):
#   pwsh -File harness/scripts/check.ps1
#
# Exits 0 only when every check passed, matching the tools/verify.ps1 contract.

[CmdletBinding()]
param()

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$results = [System.Collections.Generic.List[object]]::new()
$failed = 0

function Add-Check {
    param([string]$Name, [bool]$Ok, [string]$Detail = "")
    $script:results.Add([pscustomobject]@{ Name = $Name; Passed = $Ok })
    if (-not $Ok) { $script:failed++ }
    $label = if ($Ok) { "PASS" } else { "FAIL" }
    Write-Host ("[{0}] {1}" -f $label, $Name)
    if (-not $Ok -and $Detail -ne "") { Write-Host "      $Detail" }
}

function Test-PathRelative {
    param([string]$Relative)
    Test-Path -LiteralPath (Join-Path $root $Relative)
}

function Read-Relative {
    param([string]$Relative)
    Get-Content -Raw -LiteralPath (Join-Path $root $Relative)
}

# 1. Every file the harness promises exists, plus the repository sources the
#    profile points at. A moved doc must fail here, not misdirect an agent.
$requiredPaths = @(
    "harness/project.md",
    "harness/README.md",
    "harness/scripts/check.ps1",
    "harness/scripts/evidence.ps1",
    "harness/templates/design-brief.md",
    "harness/templates/playtest-report.md",
    "harness/templates/milestone-verdict.md",
    "harness/templates/art-brief.md",
    "AGENTS.md",
    "README.md",
    "game/README.md",
    "tools/verify.ps1",
    "docs/GAME_DESIGN_FOUNDATION.md",
    "docs/DEVELOPMENT_PLAN.md",
    "docs/MILESTONES.md",
    "docs/BACKLOG.md",
    "docs/CREATIVE_EXPLORATION_PLAN.md",
    "creative/muse/README.md"
)
foreach ($p in $requiredPaths) {
    Add-Check "file: $p" (Test-PathRelative $p) "missing $p"
}

# 2. Every skill is discoverable, documented and reads the profile first.
$skillIds = @("game-design", "game-build", "game-feel", "game-verify", "game-art", "game-scope")
foreach ($id in $skillIds) {
    $relative = ".agents/skills/$id/SKILL.md"
    $exists = Test-PathRelative $relative
    Add-Check "skill file: $id" $exists "missing $relative"
    if (-not $exists) { continue }

    $text = Read-Relative $relative
    $hasFrontmatter = ($text -match '(?m)^name:\s*\S+') -and ($text -match '(?m)^description:\s*\S+')
    Add-Check "skill frontmatter: $id" $hasFrontmatter "needs name: and description: in frontmatter"
    Add-Check "skill reads profile: $id" ($text -match 'harness/project\.md') "must reference harness/project.md"
}

# 3. The profile keeps the sections a skill depends on.
$profile = "harness/project.md"
if (Test-PathRelative $profile) {
    $text = Read-Relative $profile
    $headings = @(
        "## Project",
        "## Engine",
        "## Commands",
        "## Repository map",
        "## Decision rules",
        "## Scope guard",
        "## Creative",
        "## Sources"
    )
    foreach ($h in $headings) {
        Add-Check "profile heading: $h" ($text -match [regex]::Escape($h)) "missing heading $h"
    }
}

# 4. Every command exists, is listed in command discovery, and names a real
#    skill. A command that points at a missing skill is a broken entry point.
$commandIds = @("game-design", "game-build", "game-verify", "game-feel", "game-art", "game-scope")
foreach ($id in $commandIds) {
    $relative = ".opencode/commands/$id.md"
    $exists = Test-PathRelative $relative
    Add-Check "command: /$id" $exists "missing $relative"
    if (-not $exists) { continue }

    $text = Read-Relative $relative
    Add-Check "command description: /$id" ($text -match '(?m)^description:\s*\S+') "needs description: in frontmatter"
    $namesSkill = $text -match "(?<![a-z-])$id(?![a-z-])"
    $skillExists = Test-PathRelative ".agents/skills/$id/SKILL.md"
    Add-Check "command maps to skill: /$id" ($namesSkill -and $skillExists) "must name $id and that skill must exist"
}

# 5. The harness README is the entry point; it must name the pieces.
if (Test-PathRelative "harness/README.md") {
    $readme = Read-Relative "harness/README.md"
    foreach ($token in @("project.md", "check.ps1", "evidence.ps1")) {
        Add-Check "README names: $token" ($readme -match [regex]::Escape($token)) "harness/README.md must mention $token"
    }
}

Write-Host ""
if ($results.Count -eq 0) {
    Write-Host "HARNESS CHECK FAILED: no checks ran" -ForegroundColor Red
    exit 1
}
if ($failed -gt 0) {
    Write-Host ("HARNESS CHECK FAILED: {0} of {1} checks failed" -f $failed, $results.Count) -ForegroundColor Red
    exit 1
}
Write-Host ("HARNESS CHECK PASSED: {0} checks" -f $results.Count) -ForegroundColor Green
exit 0
