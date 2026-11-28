# Pulse Maw one-cycle pilot — Gines

Status: PLANNED (approved to start; no implementation claim). Base: reviewed Gines asset refresh PR #7 head 99d307004f0746428547003487cb7837dbb04fab. Branch: dot/pulse-maw-pilot. Counterpart: rua-den/assets-creator:dot/pulse-maw-pilot.

## Cross-repo contract v1

The approved pilot is exactly one attack cycle in an isolated Gines demo using a real Assets Creator Rust pack. It is not the three-beat encounter. Default Map 04, campaign, official milestones, player hitboxes, energy, save format, level geometry and the other maps remain unchanged. P2+ must not start automatically.

- State flow: READY → WARN (differentiated outline plus persistent radius indicator) → BEAT (one hit evaluation, one audio cue) → INHALE (target can receive damage) → READY. The warning locks its center once and never follows the player. Prototype defaults: 0.80 s warning, 0.20 s impact presentation, 1.40 s inhale, 0.40 s idle, radius 120 px. Numbers are proposed, not final tuning. Game clock owns timing and geometric hit test; FPS/audio durations never affect damage. No enemy damage to the player outside the locked circle. Leave stock player damage/invulnerability/energy behavior intact. Retry clears stale effects and pending callbacks while preserving evolution/nutrition. Audio is optional for readability.
- Pack format: one zip with root manifest.json, assets/genesis/pulse_maw/telegraph.png, assets/genesis/pulse_maw/telegraph.tres, assets/genesis/pulse_maw/beat.wav. Stable logical IDs telegraph and beat; manifest schema_version=1, pack_id=pulse_maw_pilot, seed, generator_commit (40 hex), files list of exact relative paths and SHA256, visual metadata {frame_width:256, frame_height:256, frames:8, fps:12, loop:false, anchor:[128,128]}, audio metadata {channels:1, sample_rate:44100}. Telegraph uses one or more clearly open/contrasting shapes; its non-looping strip plays within the game-owned warning, while code holds an always-visible semantic outline until impact. All files under pack root; no executable resources or runtime download. The .tres references res://assets/genesis/pulse_maw/telegraph.png, default sequence, nonlooping. Gines can keep an untracked fixture while developing but release evidence must use the exact genuine generated archive, verified checksum and generator commit. Missing asset/invalid contract fails strict integration.
- Presentation: run real Godot 4.7.2 rendered demo at 960x540, capture warning, pulse and inhale (and produce a short clip if available), compare same scene/camera with baseline Map 04 where useful. Evidence must include exact revisions, artifact SHA, commands, observed results and explicit limits. Optional sound vs. silence must never change logic. No human feel, Windows portable, production feature or full boss completion claims in this pilot.
- Status ownership: agent records WORKING or READY_FOR_REVIEW and evidence. Independent reviewer verifies exact head and negative controls. Root marks PASS only for a named scope with successful runtime evidence plus independent review; maintain separate Rust, Gines, integrated and human status. If a gate fails, record failure, fix in current checkpoint, and rerun. Main and Gines PR #7 are not changed or merged by this pilot.

## Gines workstream

1. Implement an opt-in demo scene or explicit dev path modeled on Map 04, reusing the existing player/checkpoint and backdrop where practical. Do not change the canonical Map 04 JSON, normal campaign routing, M4/M5 verdicts, hazard floor or Map 05 progression. Keep pilot target independently testable.
2. Separate deterministic state logic, phase transitions and presentation; use the pack visuals for WARN and real WAV for accepted BEAT, default resource contract checked before capture. Inhale has readable visual state. Confirm exactly one hit per cycle, no duplicate cue, refusal outside inhale, success inside inhale, and low-energy recovery. Test boundary (inside/outside), center remains locked after player moves, pause/retry cancel stale visuals, effects and actions. Intentionally invalidate an input or file to prove strict gate fails.
3. Run real Godot import, focused pilot tests and existing campaign regression (latest baseline 53 full checks) without widening claims. Provide exact diff, before/after or sequence capture, and known limitations. Only the root after review marks this checklist.

## Evidence status

| Gate | Status | Evidence |
|---|---|---|
| Draft plan | PLANNED | User approved pilot start |
| Gines one-cycle test | NOT RUN | none |
| Genuine Rust pack integration | NOT RUN | none |
| Rendered evidence and independent review | NOT RUN | none |
| Human feel / full three-beat scope | OUT OF SCOPE | not approved by this checkpoint |
