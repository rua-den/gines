# CHR-001 — Protagonist Evolution Lineup

- **Status:** Exploration (owner has not reviewed; not a direction)
- **Version:** v01
- **Created:** 2026-11-21
- **Category:** character
- **Source:** hand-authored SVG concept sheet (Muse image generation attempted first, see Provenance)
- **Prompt:** see `CHR-001_evolution-lineup_v01.prompt.md`

## Provenance

The AI image-generation request was attempted with the prompt linked above but
failed with `Insufficient balance` (pay-as-you-go image credits). It was **not**
retried. To keep the exploration moving without spending credits, this v01 is a
deterministic SVG vector sketch authored from the same brief. The PNG path that
was attempted was never written; do not treat it as an alternative version.

## Visual intent

Five stages of one nameless organism on a dark field, left→right:
1. single cell with cilia;
2. elongated swimmer with an absorbing vacuole;
3. the same body with an earned ring of short golden spines (the implemented
   burst motif);
4. a differentiated body with a clear front/back and one directional part;
5. an elegant late pre-birth form that is still recognizably the same creature,
   not a miniature adult human.

The first thing to notice is the **warm gold nucleus** and the related silhouette
rhythm that survive every transformation.

## Design observations

- Palette: teal/sea-green translucent tissue, warm gold nucleus and accents,
  near-black desaturated background, selective rim light.
- Shapes: soft membranes, cilia, one focal nucleus; spines appear only at stage
  3 so the upgrade reads as a change, not decoration.
- Stage 4 introduces a directional fin/part; stage 5 layers membranes and small
  buds but keeps the same central core.

## Animation / production budget

2D frame-by-frame at 960×540. This sheet implies **one reusable body shape per
stage** with a small state set (idle, swim/crawl, grip, burst). The spike ring
would reuse one radial element. No unique frame sets are implied for the five
stages — a solo developer could keep this as a family of gradients and a few
overlay parts, matching what the prototype currently draws procedurally.

## Gameplay hypotheses (ideas, not decisions)

- Stage 1–2: cilia and vacuole suggest swimming, channel-hold absorption.
- Stage 3: the gold spike ring is the `spike_burst` body weapon already in code.
- Stage 4: a directional part suggests a frontal strike, but that ability is
  **planned**, not implemented.
- Stage 5: layered buds could suggest sensing or protection; no mechanic decided.

## Strengths

- Clear continuity cue (nucleus + silhouette rhythm) across all five forms.
- Spike stage maps to an ability that actually exists in the build.
- Cheap to reproduce: vector shapes and gradients, no texture assets.

## Questions / risks

- Vector gradients currently ship in the prototype; this sheet does not solve
  the frame-by-frame animation cost question.
- No approved art direction exists; the palette is a proposal only.
- Stage 5 may read too abstract to carry the emotional "become human" beat —
  owner review needed.
- Does not imitate a named game, but still needs comparison against the visual
  identity brief before any refinement.

## Next iteration

- Owner reviews for continuity and the stage-3 weapon read.
- If direction is promising, refine the two **implemented** stages first
  (cell → spike ring) and defer the planned forms.
- Consider a separate palette exploration before adding more detail.
