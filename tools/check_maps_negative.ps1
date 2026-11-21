param(
	[string]$MapsDir = ""
)

# Reproducible negative controls for tools/check_maps.ps1.
# Creates temporary copies of the canonical maps, breaks exactly one rule in
# each, and asserts the checker fails with that rule's name. Read-only on the
# repository: all mutations happen in a temp directory that is removed at exit.

$root = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($MapsDir)) {
	$MapsDir = Join-Path $root 'docs/maps'
}
$source = (Resolve-Path -LiteralPath $MapsDir -ErrorAction SilentlyContinue)
if ($null -eq $source) {
	Write-Output "MAP NEGATIVE FAILED — maps directory not found: $MapsDir"
	exit 1
}
$checker = Join-Path $PSScriptRoot 'check_maps.ps1'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('genesis-map-negative-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

$fixtures = @(
	@{ name = 'missing_obstacles'; file = 'map03.json'; rule = 'at least 2 obstacles are required' },
	@{ name = 'broken_chain'; file = 'map04.json'; rule = 'exit_unlocks must be map05' },
	@{ name = 'dishonest_status'; file = 'map07.json'; rule = 'implemented upgrade id is not in the build whitelist' },
	@{ name = 'maternal_boss'; file = 'map08.json'; rule = 'boss.kind must be hostile_organism (never the mother)' },
	@{ name = 'second_meter'; file = 'map06.json'; rule = 'resources.meter_count must be 1' },
	@{ name = 'softlock_silence'; file = 'map05.json'; rule = 'upgrade.softlock_fallback is required' },
	@{ name = 'future_gate'; file = 'map05.json'; rule = 'must be owned by stage 5 or earlier' },
	@{ name = 'hazard_no_fallback'; file = 'map04.json'; rule = 'planned obstacle needs fallback_until_implemented' },
	@{ name = 'linear_model'; file = 'map02.json'; rule = 'progression.model must be illustrative_linear' }
)

function Break-Fixture([string]$Name, [string]$Path) {
	$json = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
	switch ($Name) {
		'missing_obstacles' { $json.obstacles = @() }
		'broken_chain' { $json.progression.exit_unlocks = 'map99' }
		'dishonest_status' { $json.upgrade.engine_status = 'implemented' }
		'maternal_boss' { $json.boss.kind = 'mother' }
		'second_meter' { $json.resources.meter_count = 2 }
		'softlock_silence' { $json.upgrade.softlock_fallback = '' }
		'future_gate' { $json.boss.gate_requires = @('double_jump_glide') }
		'hazard_no_fallback' {
			$hazard = @($json.obstacles | Where-Object { $_.kind -eq 'hazard_zone' } | Select-Object -First 1)[0]
			if ($null -eq $hazard) { throw "no hazard_zone in $Path" }
			$hazard.PSObject.Properties.Remove('fallback_until_implemented')
		}
		'linear_model' { $json.progression.model = 'connected_world' }
		default { throw "unknown fixture $Name" }
	}
	$json | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $Path
}

$failures = [System.Collections.Generic.List[string]]::new()
foreach ($fixture in $fixtures) {
	$dir = Join-Path $tempRoot $fixture.name
	New-Item -ItemType Directory -Path $dir -Force | Out-Null
	Copy-Item -Path (Join-Path $source.Path 'map*.json') $dir
	$target = Join-Path $dir $fixture.file
	Break-Fixture $fixture.name $target
	$output = & pwsh -NoProfile -File $checker -MapsDir $dir 2>&1 | Out-String
	$exit = $LASTEXITCODE
	$ok = ($exit -eq 1) -and ($output -match [regex]::Escape($fixture.rule))
	Write-Output ("[{0}] {1} — exit={2} rule='{3}'" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $fixture.name, $exit, $fixture.rule)
	if (-not $ok) { $failures.Add($fixture.name) }
}

Write-Output ("negative controls: {0}/{1} passed" -f ($fixtures.Count - $failures.Count), $fixtures.Count)

try { Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue } catch { }

if ($failures.Count -gt 0) {
	Write-Output ("MAP NEGATIVE FAILED — {0} fixture(s): {1}" -f $failures.Count, ($failures -join ', '))
	exit 1
}
Write-Output 'MAP NEGATIVE PASSED — 9 fixtures failed as named'
exit 0
