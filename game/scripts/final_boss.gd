class_name FinalBoss
extends BloomBoss
## The Convergence — the ninth-stage final boss. A distinct two-phase organism
## built on BloomBoss's proven, tested rhythm: no new resource, input or damage
## rule is introduced. Phase 1 is the learned Rot Bloom timing (0.6 / 1.5), so
## the player can read it immediately. At half health it enters `second_wind`:
## the telegraph shortens to 0.45 s and the weak window narrows to 1.1 s. The
## transition is published on `phase_changed` as a readable `second_wind`
## marker, and subsequent phase labels carry it too.
##
## Inherited rules are untouched: damage is accepted only while `phase ==
## "exposed"`, the boss hurts only during `attack`, it joins the `predator`
## group, and `defeated` fires exactly once.
##
## GDScript forbids redeclaring an inherited member, so the 12-HP value lives in
## FINAL_MAX_HEALTH and is exposed via max_health(); the instance's `health`
## starts and resets at 12 while BloomBoss itself is unchanged.

const FINAL_MAX_HEALTH := 12
const SECOND_WIND_HEALTH := 6
const TELEGRAPH_SECOND_WIND := 0.45
const WEAK_WINDOW_SECOND_WIND := 1.1
const SECOND_WIND_MARKER := "second_wind"

## Public, readable phase state. Tests and HUD can inspect it without reaching
## into private timing fields.
var second_wind: bool = false


func _init() -> void:
	# GDScript resolves the base class's `health = MAX_HEALTH` initializer to
	# BloomBoss.MAX_HEALTH (6), so the subclass must set its own full health.
	health = FINAL_MAX_HEALTH


func _art_key() -> String:
	return "final_boss"


func max_health() -> int:
	return FINAL_MAX_HEALTH


func telegraph_duration() -> float:
	return TELEGRAPH_SECOND_WIND if second_wind else TELEGRAPH


func weak_window_duration() -> float:
	return WEAK_WINDOW_SECOND_WIND if second_wind else WEAK_WINDOW


func _duration_for(p: String) -> float:
	match p:
		"telegraph":
			return telegraph_duration()
		"exposed":
			return weak_window_duration()
	return super._duration_for(p)


## The second wind triggers the moment the threshold is crossed, not on a later
## frame, so `phase_changed` carries an unambiguous, observable marker.
func take_damage(amount: int) -> bool:
	var landed: bool = super.take_damage(amount)
	if landed and not is_defeated and not second_wind and health <= SECOND_WIND_HEALTH:
		second_wind = true
		phase_changed.emit(SECOND_WIND_MARKER)
	return landed


func reset() -> void:
	super.reset()
	# super.reset() uses BloomBoss.MAX_HEALTH; restore this boss's own health.
	health = FINAL_MAX_HEALTH
	second_wind = false


## Attach the readable marker to every phase label emitted after the turn.
func _phase_label() -> String:
	var label: String = super._phase_label()
	return SECOND_WIND_MARKER + ":" + label if second_wind else label
