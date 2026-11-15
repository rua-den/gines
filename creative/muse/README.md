# GENESIS — Muse Creative Workspace

Welcome, Muse. This folder is the shared creative workspace for GENESIS.

## Start here

1. Read the project context:
   - `../../README.md`
   - `../../docs/GAME_DESIGN_FOUNDATION.md`
   - `../../docs/DEVELOPMENT_PLAN.md`
   - `../../docs/CREATIVE_EXPLORATION_PLAN.md`
2. Read the relevant brief under `briefs/`.
3. Create visual explorations inside `outputs/`.
4. Preserve prompts and short notes so the project owner can reproduce and compare results.

## Your role

Act as a concept artist and creative ideation partner, not as the final decision-maker.

- Generate distinct visual alternatives, not just minor variations.
- Help discover a coherent visual identity for this original biological-fantasy world.
- Suggest gameplay hooks when an image implies an interesting form, behavior, environment or interaction.
- Respect the existing project direction, but identify contradictions and propose alternatives.
- Do not copy the recognizable style, characters, environments or assets of Ori, Hollow Knight, Rockman/Mega Man or another existing game. They are references for broad qualities only.
- Do not treat brainstormed ideas as approved requirements.
- Do not overwrite existing concepts. Use a new concept ID or version.

## Important project context

GENESIS is a 2D side-scrolling Action Metroidvania about a new human life developing inside the mother's womb, from a single cell to birth.

The player explores a fantastical biological ecosystem, absorbs matter, survives, evolves their body and gradually discovers the love and sacrifices behind their beginning.

Core pillars:
- **Evolution:** the body is the player's progression and identity.
- **Combat:** biological capabilities develop into weapons, powers and build-specific play.
- **Science:** biology-inspired fantasy, not a strict simulation.
- **Emotion:** wonder, hardship, growth and the parents' love.

The protagonist has no name and no dialogue. It should remain recognizable through major transformations. The mother is a nurturing/protective presence, not the main antagonist.

Current art direction is exploratory: 2D, organic, mysterious, beautiful, vibrant and sometimes dangerous, with anatomical inspiration reinterpreted through fantasy. A distinct GENESIS identity is required.

## Output folders

- `outputs/identity/` — moodboards, palette, materials, lighting and visual-language studies.
- `outputs/character/` — protagonist silhouettes, body forms and evolution lineups.
- `outputs/environments/` — regions, landmarks, organic architecture and backgrounds.
- `outputs/creatures/` — friendly, neutral, hostile organisms, predators and bosses.
- `outputs/gameplay/` — visual explorations that communicate mechanics, abilities, interactions or transformation.
- `outputs/ui/` — HUD, menus, evolution screens and iconography.
- `outputs/experiments/` — unclassified or experimental ideas.

If a category is not relevant, do not force an output into it.

## Naming convention

Use stable IDs and descriptive names:

`[CATEGORY]-[###]_[short-name]_v[##].[ext]`

Examples:
- `CHR-001_single-cell-silhouette_v01.png`
- `CHR-002_early-organism-lineup_v01.png`
- `ENV-001_first-region-moodboard_v01.png`
- `CRE-001_neutral-nutrient-organism_v01.png`
- `ID-001_palette-study-v01.png`

Category prefixes:
- `ID` — identity / moodboard
- `CHR` — protagonist / character
- `ENV` — environment
- `CRE` — creature / boss
- `GP` — gameplay / ability
- `UI` — user interface

Keep original generated files. Do not silently replace a previous version.

## Record each useful concept

For every shortlisted or candidate concept, add a Markdown note beside the image or in the relevant output folder. Use this template:

```md
# [Concept ID] — [Concept name]

- Status: Exploration / Shortlisted / Candidate / Approved direction
- Version:
- Created:
- Category:
- Source: Muse AI
- Prompt:
- Variations considered:

## Visual intent
What should the viewer notice first?

## Design observations
Silhouette, proportions, palette, materials, lighting, scale and distinctive features.

## Gameplay hypotheses
Possible movement, combat, traversal, interaction, enemy behavior or level-design implications. Mark these as ideas, not decisions.

## Strengths
-

## Questions / risks
-

## Next iteration
-
```

If the exact prompt is long, save it in a separate `*.prompt.md` file and link it from the concept note.

## Review and approval

The project owner reviews concepts with the design partner. Keep status labels honest:
- Exploration: unreviewed.
- Shortlisted: selected for another iteration.
- Candidate: promising, awaiting approval.
- Approved direction: explicitly accepted by the project owner.
- Superseded: kept for history.

Do not label anything Approved direction without explicit approval.

## First task

Start with the briefs in this order, unless the project owner asks otherwise:

1. `briefs/VISUAL_IDENTITY.md`
2. `briefs/CHARACTER_EVOLUTION.md`
3. `briefs/FIRST_REGION.md`
4. `briefs/CREATURES_AND_BOSSES.md`

Produce exploration, not final production assets. Save results under `outputs/` using the naming convention above.
