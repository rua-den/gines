# M5 boss demo captures — evidence note

Status: verification evidence (not a concept; no approval status applies).

The four PNG files below are **automated demo evidence captures** produced by the
`--m5-demo` autopilot in `game/scripts/boss_fight.gd`. They are not Muse concept
explorations. They are therefore exempt from the concept-ID naming convention
(`[CATEGORY]-[###]_[short-name]_v[##].[ext]`) and the per-concept note template
described in `creative/muse/README.md` (Naming convention / Record each useful
concept). They are kept under their existing exact names because the M5 plan,
verification evidence and committed captures reference those names; do not rename
them. This note is the accompanying record in place of a concept note.

## Files

- `M5_boss-approach_v01.png` — the player approaching the Rot Bloom arena after
  evolving and crossing the gate; captured when the boss comes within ~380 px
  during the approach stage.
- `M5_boss-telegraph_v01.png` — the boss in its `telegraph` phase, showing the
  incoming-attack tell before the vulnerable window opens.
- `M5_boss-weak-window_v01.png` — the boss in its `exposed` phase, the only
  window in which an evolved spike burst can damage it.
- `M5_boss-victory_v01.png` — the post-defeat state after the boss is beaten.

## Regeneration

From the repository root (the `--outdir` must be absolute; Godot resolves
relative paths against `game/`):

```powershell
& "D:\stu\gd\clone-game\tools\godot\Godot_v4.7.2-stable_win64_console.exe" --audio-driver Dummy --path game res://scenes/boss_test.tscn -- --m5-demo --outdir="$(Get-Location)/creative/muse/outputs/experiments" --fresh-save
```

A display-capable run is required for the viewport screenshots to be written; a
headless run cannot capture images (`_save_capture` has no viewport image) and is
expected to fail that criterion rather than regenerate the PNGs.

These captures document runtime behaviour only. They do not establish or approve
any art direction.
