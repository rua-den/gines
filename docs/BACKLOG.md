# GENESIS — Initial Backlog

**Current phase:** Phase 0 — Foundation & Pre-production  
**Next implementation target:** Core Prototype  
**Planning note:** These are ordered work items, not calendar deadlines.  
**Milestone decisions:** recorded in [`MILESTONES.md`](MILESTONES.md) — a checked box is not a milestone PASS.

## Milestone 0 — Project setup

- [x] Create Godot project and verify it opens/runs.
  - Acceptance: project launches into a test scene without errors.
- [x] Establish repository structure and naming conventions.
  - Acceptance: folders are documented and consistently named.
- [x] Configure input actions.
  - Acceptance: keyboard/controller actions are centrally defined.
- [x] Define target resolution, viewport scaling and pixel/HD rendering approach.
  - Acceptance: test scene scales correctly across selected window sizes.
- [x] Add a minimal README and development notes.
  - Acceptance: a new contributor can run the project using the instructions.

## Milestone 1 — Player movement

- [x] Create player scene and controller.
  - Acceptance: player can move in a bounded test environment.
- [x] Implement swimming movement.
  - Acceptance: acceleration, deceleration and directional control feel predictable.
- [x] Implement crawling.
  - Acceptance: player can move along a test surface.
- [x] Prototype surface gripping.
  - Acceptance: player can attach, remain attached and detach intentionally.
- [x] Add collision and environment boundaries.
  - Acceptance: no unintended tunneling or getting stuck in the test area.
- [x] Add basic camera follow.
  - Acceptance: player remains framed without distracting camera motion.

## Milestone 2 — Absorption & survival

*Automated acceptance met 2026-11-19; the human "understandable and satisfying"
check is still open in `MILESTONES.md`.*

- [x] Define a minimal biological resource data model.
  - Acceptance: one resource can be collected and displayed/debugged.
  - Evidence: `player.nutrition` + `nutrition_gained` signal; HUD `Nutrition N`.
- [x] Create one absorbable organism or environmental object.
  - Acceptance: object can be detected and absorbed through a clear interaction.
  - Evidence: four motes, `interact` held inside 90 px for 0.75 s.
- [x] Implement absorption feedback.
  - Acceptance: player receives immediate visual/audio/UI feedback.
  - Evidence: pulse, burst, HUD flash and channel percentage. **Visual/UI only —
    the project has no audio assets yet**, so there is no audio feedback.
- [x] Create one hostile organism.
  - Acceptance: enemy can detect or engage the player in a simple test.
  - Evidence: patrols x 1000–1520, chases inside 420 px, contacts for damage.
- [x] Implement basic damage and survival.
  - Acceptance: damage, invulnerability/response and defeat states are testable.
  - Evidence: `tests/survival_check.gd` 6/6 — contact, 1 s invulnerability,
    expiry, defeat once, revive.
- [x] Add a basic recovery or restart flow.
  - Acceptance: player can retry the test without restarting the application.
  - Evidence: defeat overlay → `interact` revives in place; nutrition persists.


## Milestone 3 — First evolution

- [ ] Define one evolution requirement.
  - Acceptance: requirement can be inspected and tested.
- [ ] Create one evolution zone.
  - Acceptance: player can activate it when requirements are met.
- [ ] Implement one body transformation.
  - Acceptance: character appearance changes visibly.
- [ ] Connect the new body part to one ability.
  - Acceptance: ability is unavailable before evolution and usable afterward.
- [ ] Add evolution feedback.
  - Acceptance: transition communicates that a permanent change occurred.
- [ ] Save and reload the evolution state.
  - Acceptance: evolution persists across a save/load cycle.

## Prototype acceptance gate

The prototype passes when a player can:

1. Move through a small biological test environment.
2. Swim, crawl and grip a surface.
3. Find and absorb at least one biological resource.
4. Avoid or confront one hostile organism.
5. Meet an evolution requirement.
6. Trigger one evolution.
7. Use the newly acquired ability.

The loop must be understandable and enjoyable enough to justify building a vertical slice.

## Explicitly out of scope

- Full world map.
- Multiple complete regions.
- All developmental stages.
- Full evolution tree.
- Five separate resource systems.
- Multiple bosses.
- Final UI, final art and complete soundtrack.
- Steam release infrastructure.
