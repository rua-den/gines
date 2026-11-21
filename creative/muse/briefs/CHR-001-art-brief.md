# Art Brief — CHR-001 Protagonist Evolution Lineup

**Date:** 2026-11-21
**Status:** Exploration
**Related design:** `docs/GAME_DESIGN_FOUNDATION.md` §5, §7, §10; `creative/muse/briefs/CHARACTER_EVOLUTION.md`

## Intent

One side-by-side concept sheet showing the same nameless protagonist at five
illustrative stages: single cell → early swimming organism → spiked first
evolution → differentiated body → late pre-birth form. This is a reviewable
visual hypothesis for "Become Human", not a sprite sheet.

## Gameplay / emotional purpose

At 960×540 the viewer must read *continuity* (the same central nucleus and
silhouette rhythm survives every change) and *growth* (vulnerable → capable).
The spike stage must read as an earned body change with a weapon/ability,
not a temporary buff icon. It must not be mistaken for a conventional armored
hero, a horror creature, or the mother.

## Constraints

- 960×540 base, Godot 4.7.2 gl_compatibility, 2D side-scrolling.
- Frame-by-frame budget: keep shapes reusable; this concept should imply a
  small number of states (idle, swim/crawl, grip, burst) per stage, not
  unique frame sets for every form.
- Palette: muted teal/sea-green tissue, warm gold nucleus/accent, deep
  desaturated background; selective bioluminescent rim, not uniform glow.
- No named-game imitation (Ori, Hollow Knight, Mega Man and similar are
  broad quality references only). No gore, no horror styling.
- Procedural gradients are what the prototype can actually ship today; this
  image explores a direction, not a committed production asset.

## Composition and silhouette

Horizontal lineup, five stages left→right, equal baseline scale, dark
near-black background, thin gold divider ticks. Each form keeps a bright
central nucleus and a soft outer membrane. Stage progression:
1. small translucent cell with one nucleus and a few cilia;
2. elongated swimming form with ciliated edge and a visible absorbing vacuole;
3. same body with a ring of short golden spines (the implemented burst motif);
4. differentiated form with a clear front/back and one directional body part;
5. elegant late pre-birth form, recognizable but not a miniature adult human.

## References

Real biology: cell membranes, cilia, vacuoles, mineral deposition, limb buds.
Conceptual mood only: wonder, vulnerability, gradual capability. No specific
game, artist or studio style is copied.

## Deliverables

- One concept sheet: `creative/muse/outputs/character/CHR-001_evolution-lineup_v01.png`
- Prompt saved in `CHR-001_evolution-lineup_v01.prompt.md`
- Concept note beside the image, status Exploration.

## Acceptance criteria

- [ ] Reads at 960×540 without explanation.
- [ ] Continuity cue (nucleus + silhouette rhythm) survives all five stages.
- [ ] Spike stage reads as the earned burst ability, not decoration.
- [ ] Animation/asset cost fits the stated budget.
- [ ] Owner review pending; status set only by owner.

## Risks

| Risk | Mitigation |
|---|---|
| Beautiful but unaffordable frame-by-frame cost | keep forms simple and reusable; note budget in concept note |
| Drifts toward a named reference's style | prompt forbids imitation; review against identity brief |
| Implies approved direction | label Exploration everywhere; do not edit official design docs |

## Next iteration

- After owner review: refine silhouettes for the two implemented stages;
  decide whether to explore a separate palette direction first.
