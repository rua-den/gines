param(
	[string]$MapsDir = ""
)

# Design-only validator for docs/maps/mapNN.json. Read-only: never writes a file.
$root = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($MapsDir)) {
	$MapsDir = Join-Path $root 'docs/maps'
}
$resolved = Resolve-Path -LiteralPath $MapsDir -ErrorAction SilentlyContinue
if ($null -eq $resolved) {
	Write-Output "MAP CHECK FAILED — maps directory not found: $MapsDir"
	exit 1
}
$MapsDir = $resolved.Path

$script:errors = [System.Collections.Generic.List[string]]::new()
$script:checks = 0

function Check([bool]$Condition, [string]$File, [string]$Rule) {
	$script:checks++
	if (-not $Condition) {
		$script:errors.Add("[$File] $Rule")
	}
}

$implementedUpgrades = @('surface_grip', 'crawl', 'absorption_channel', 'spike_ring', 'spike_burst', 'energy_pool')
$implementedBosses = @('rot_bloom')
$implementedObstacleKinds = @('static_slab', 'gate')
$validObstacleKinds = @('static_slab', 'gate', 'hazard_zone')
$statuses = @('implemented', 'planned')

$files = @(Get-ChildItem -LiteralPath $MapsDir -Filter 'map*.json' -File | Sort-Object Name)
Check ($files.Count -eq 8) 'directory' ("expected 8 map files, found {0}" -f $files.Count)

$parsed = @{}
foreach ($file in $files) {
	$name = $file.Name
	try {
		$map = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
	} catch {
		$script:errors.Add("[$name] invalid JSON: $($_.Exception.Message)")
		continue
	}
	$parsed[$name] = $map

	if ($name -notmatch '^map(\d{2})\.json$') {
		$script:errors.Add("[$name] filename does not match mapNN.json")
		continue
	}
	$stageNumber = [int]$Matches[1]
	$expectedId = $name -replace '\.json$', ''

	Check ($map.artifact_type -eq 'design_only') $name 'artifact_type must be "design_only"'
	Check ($map.schema_version -eq 1) $name 'schema_version must be 1'
	Check ($map.id -eq $expectedId) $name 'id must match filename'
	Check ($map.stage -eq $stageNumber) $name 'stage must match filename number'
	Check (-not [string]::IsNullOrWhiteSpace([string]$map.name)) $name 'name is required'
	Check (@($map.plan_refs).Count -ge 1) $name 'plan_refs must name at least one source'

	Check ($null -ne $map.room) $name 'room is required'
	if ($null -ne $map.room) {
		Check ($map.room.width -eq 1920) $name 'room.width must be 1920'
		Check ($map.room.height -eq 1080) $name 'room.height must be 1080'
		Check ($map.room.coordinate_space -eq 'design_only') $name 'room.coordinate_space must be "design_only"'
	}

	$obstacles = @($map.obstacles)
	Check ($obstacles.Count -ge 2) $name 'at least 2 obstacles are required'
	$slabCount = 0
	foreach ($obstacle in $obstacles) {
		Check (-not [string]::IsNullOrWhiteSpace([string]$obstacle.id)) $name 'obstacle.id is required'
		Check ($validObstacleKinds -contains $obstacle.kind) $name 'obstacle.kind must be static_slab, gate or hazard_zone'
		Check ($statuses -contains $obstacle.engine_status) $name 'obstacle.engine_status must be implemented or planned'
		if ($obstacle.kind -eq 'static_slab') {
			$slabCount++
		}
		if ($obstacle.kind -eq 'hazard_zone') {
			Check ($obstacle.engine_status -eq 'planned') $name 'hazard_zone cannot be implemented'
		}
		if ($obstacle.engine_status -eq 'implemented') {
			Check ($implementedObstacleKinds -contains $obstacle.kind) $name 'implemented obstacle kind is not in the build whitelist'
		} else {
			Check (-not [string]::IsNullOrWhiteSpace([string]$obstacle.fallback_until_implemented)) $name 'planned obstacle needs fallback_until_implemented'
		}
		$rect = @($obstacle.rect)
		Check ($rect.Count -eq 4) $name 'obstacle.rect must have 4 numbers'
		if ($rect.Count -eq 4) {
			$inside = ($rect[2] -gt 0) -and ($rect[3] -gt 0) -and
				($rect[0] -ge 0) -and ($rect[1] -ge 0) -and
				(($rect[0] + $rect[2]) -le 1920) -and (($rect[1] + $rect[3]) -le 1080)
			Check $inside $name 'obstacle.rect must be positive and inside the room'
		}
	}
	Check ($slabCount -ge 2) $name 'at least 2 static_slab obstacles are required'

	Check ($null -ne $map.upgrade) $name 'upgrade is required'
	if ($null -ne $map.upgrade) {
		$upgrade = $map.upgrade
		Check (-not [string]::IsNullOrWhiteSpace([string]$upgrade.id)) $name 'upgrade.id is required'
		Check (@($upgrade.grants).Count -ge 1) $name 'upgrade.grants must list what it gives'
		Check ($upgrade.permanent -eq $true) $name 'upgrade.permanent must be true'
		Check ($upgrade.additive -eq $true) $name 'upgrade.additive must be true'
		Check ($statuses -contains $upgrade.engine_status) $name 'upgrade.engine_status must be implemented or planned'
		Check (-not [string]::IsNullOrWhiteSpace([string]$upgrade.softlock_fallback)) $name 'upgrade.softlock_fallback is required'
		if ($upgrade.engine_status -eq 'implemented') {
			Check ($implementedUpgrades -contains $upgrade.id) $name 'implemented upgrade id is not in the build whitelist'
		} else {
			Check (-not [string]::IsNullOrWhiteSpace([string]$upgrade.fallback_until_implemented)) $name 'planned upgrade needs fallback_until_implemented'
		}
		$upgradeImplemented = ($upgrade.engine_status -eq 'implemented')
	} else {
		$upgradeImplemented = $false
	}

	Check ($null -ne $map.boss) $name 'boss is required'
	if ($null -ne $map.boss) {
		$boss = $map.boss
		Check ($boss.kind -eq 'hostile_organism') $name 'boss.kind must be hostile_organism (never the mother)'
		Check ($statuses -contains $boss.engine_status) $name 'boss.engine_status must be implemented or planned'
		Check (@($boss.gate_requires).Count -ge 1) $name 'boss.gate_requires must name an owned upgrade'
		Check ($boss.retry_rule -eq 'shelter') $name 'boss.retry_rule must be shelter'
		Check (-not [string]::IsNullOrWhiteSpace([string]$boss.softlock_fallback)) $name 'boss.softlock_fallback is required'
		if ($boss.engine_status -eq 'implemented') {
			Check ($implementedBosses -contains $boss.id) $name 'implemented boss id is not in the build whitelist'
		} else {
			Check (-not [string]::IsNullOrWhiteSpace([string]$boss.fallback_until_implemented)) $name 'planned boss needs fallback_until_implemented'
		}
		$bossImplemented = ($boss.engine_status -eq 'implemented')
	} else {
		$bossImplemented = $false
	}

	Check ($map.checkpoint.kind -eq 'shelter') $name 'checkpoint.kind must be shelter'
	Check ($map.resources.model -eq 'single_nutrition') $name 'resources.model must be single_nutrition'
	Check ($map.resources.meter_count -eq 1) $name 'resources.meter_count must be 1'
	if ($null -ne $map.resources.future_resource) {
		Check ($map.resources.future_resource.status -eq 'Open') $name 'future_resource.status must be Open'
	}
	Check ($map.narrative.mother_role -in @('guide_only', 'absent')) $name 'narrative.mother_role must be guide_only or absent'

	$expectedStatus = if ($upgradeImplemented -and $bossImplemented) {
		'implemented'
	} elseif ($upgradeImplemented -or $bossImplemented) {
		'partial'
	} else {
		'planned'
	}
	Check ($map.stage_status -eq $expectedStatus) $name "stage_status must be derived as $expectedStatus"
}

for ($i = 1; $i -le 8; $i++) {
	$key = 'map{0:00}.json' -f $i
	if (-not $parsed.ContainsKey($key)) {
		continue
	}
	$progression = $parsed[$key].progression
	Check ($progression.model -eq 'illustrative_linear') $key 'progression.model must be illustrative_linear (linear chain is a design simplification, not the confirmed world graph)'
	if ($i -eq 1) {
		Check ($null -eq $progression.entry_requires) $key 'map01.entry_requires must be null'
	} else {
		$previous = 'map{0:00}' -f ($i - 1)
		Check ($progression.entry_requires -eq ($previous + '.boss_defeated')) $key "entry_requires must be $previous.boss_defeated"
	}
	if ($i -lt 8) {
		$next = 'map{0:00}' -f ($i + 1)
		Check ($progression.exit_unlocks -eq $next) $key "exit_unlocks must be $next"
	} else {
		Check ($progression.exit_unlocks -eq 'birth') $key 'map08.exit_unlocks must be "birth"'
	}
}

# A boss gate may only require an upgrade owned by this stage or an earlier one.
foreach ($key in $parsed.Keys) {
	$map = $parsed[$key]
	if ($null -eq $map.boss -or $null -eq $map.upgrade) {
		continue
	}
	$stage = [int]$map.stage
	$owned = [System.Collections.Generic.HashSet[string]]::new()
	foreach ($other in $parsed.Values) {
		if (([int]$other.stage -le $stage) -and ($null -ne $other.upgrade)) {
			[void]$owned.Add([string]$other.upgrade.id)
		}
	}
	foreach ($requirement in @($map.boss.gate_requires)) {
		Check ($owned.Contains([string]$requirement)) $key "boss.gate_requires '$requirement' must be owned by stage $stage or earlier"
	}
}

$upgradeIds = @($parsed.Values | ForEach-Object { [string]$_.upgrade.id })
$bossIds = @($parsed.Values | ForEach-Object { [string]$_.boss.id })
Check (($upgradeIds | Group-Object | Where-Object Count -gt 1).Count -eq 0) 'set' 'upgrade ids must be unique'
Check (($bossIds | Group-Object | Where-Object Count -gt 1).Count -eq 0) 'set' 'boss ids must be unique'

# Runtime copy drift guard: game/resources/maps/map01.json is a generated copy
# of the canonical docs/maps/map01.json. Read-only — never rewrites the copy.
$canonicalPath = Join-Path $root 'docs/maps/map01.json'
$runtimePath = Join-Path $root 'game/resources/maps/map01.json'
$canonicalHash = ''
$runtimeHash = ''
if (Test-Path -LiteralPath $canonicalPath -PathType Leaf) {
	$canonicalHash = (Get-FileHash -LiteralPath $canonicalPath -Algorithm SHA256).Hash
}
if (Test-Path -LiteralPath $runtimePath -PathType Leaf) {
	$runtimeHash = (Get-FileHash -LiteralPath $runtimePath -Algorithm SHA256).Hash
}
Check (($canonicalHash -ne '') -and ($canonicalHash -eq $runtimeHash)) 'map01.json' 'runtime map copy drifted from canonical'

# Runtime copy drift guard: game/resources/maps/map03.json is a generated copy
# of the canonical docs/maps/map03.json. Read-only — never rewrites the copy.
$canonicalPath03 = Join-Path $root 'docs/maps/map03.json'
$runtimePath03 = Join-Path $root 'game/resources/maps/map03.json'
$canonicalHash03 = ''
$runtimeHash03 = ''
if (Test-Path -LiteralPath $canonicalPath03 -PathType Leaf) {
	$canonicalHash03 = (Get-FileHash -LiteralPath $canonicalPath03 -Algorithm SHA256).Hash
}
if (Test-Path -LiteralPath $runtimePath03 -PathType Leaf) {
	$runtimeHash03 = (Get-FileHash -LiteralPath $runtimePath03 -Algorithm SHA256).Hash
}
Check (($canonicalHash03 -ne '') -and ($canonicalHash03 -eq $runtimeHash03)) 'map03.json' 'runtime map copy drifted from canonical'

# Runtime copy drift guard: game/resources/maps/map02.json is a generated copy
# of the canonical docs/maps/map02.json. Read-only — never rewrites the copy.
$canonicalPath02 = Join-Path $root 'docs/maps/map02.json'
$runtimePath02 = Join-Path $root 'game/resources/maps/map02.json'
$canonicalHash02 = ''
$runtimeHash02 = ''
if (Test-Path -LiteralPath $canonicalPath02 -PathType Leaf) {
	$canonicalHash02 = (Get-FileHash -LiteralPath $canonicalPath02 -Algorithm SHA256).Hash
}
if (Test-Path -LiteralPath $runtimePath02 -PathType Leaf) {
	$runtimeHash02 = (Get-FileHash -LiteralPath $runtimePath02 -Algorithm SHA256).Hash
}
Check (($canonicalHash02 -ne '') -and ($canonicalHash02 -eq $runtimeHash02)) 'map02.json' 'runtime map copy drifted from canonical'

if ($script:errors.Count -gt 0) {
	foreach ($failure in $script:errors) {
		Write-Output "[FAIL] $failure"
	}
	Write-Output ("MAP CHECK FAILED — {0} failures, {1} checks, {2} maps" -f $script:errors.Count, $script:checks, $files.Count)
	exit 1
}

Write-Output ("MAP CHECK PASSED — {0} maps, {1} checks" -f $files.Count, $script:checks)
exit 0
