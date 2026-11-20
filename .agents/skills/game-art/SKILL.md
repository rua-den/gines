---
name: Game Art
description: Write Muse art briefs, review generated concepts, and protect the visual direction — silhouette, palette, readability, animation budget and exploration status. Use before generating art, when reviewing concepts, or when a visual direction decision comes up.
---

# Game Art

Art is exploration until the project owner approves a direction. This skill
keeps generation useful, consistent and affordable for a solo developer.

## First

1. Read `harness/project.md` (creative rules, engine, resolution).
2. Read `creative/muse/README.md` and the current direction in
   `docs/CREATIVE_EXPLORATION_PLAN.md`. Read the latest approved or shortlisted
   concept notes before writing anything new.
3. If the request is a direction decision rather than a single asset, load the
   `brainstorming` skill.

## Workflow

1. **Write the brief** with `harness/templates/art-brief.md`: intent,
   gameplay or emotional purpose, constraints, composition and silhouette,
   palette, animation budget, deliverables, acceptance criteria.
2. **State the budget.** 2D frame-by-frame at 960×540. Name how many frames,
   states or variants the concept implies and whether a solo developer can
   animate it. Prefer reusable, readable shapes.
3. **Generate or request output** into the documented category folder under
   `creative/muse/outputs/` with a concept ID. Never overwrite an existing
   version; create the next one and keep the prompt.
4. **Review** each concept against: gameplay value, consistency with the
   direction, emotional impact, readability at game scale, and production cost.
   Use a table with strengths, risks and next iteration.
5. **Keep status honest.** Exploration → Shortlisted → Candidate → Approved
   direction → Superseded. Only the owner approves.
6. **Write the concept note** next to the useful outputs: visual intent,
   gameplay hypothesis, strengths, risks, next iteration.

## Must not

- Imitate the recognizable style or assets of a named game, artist or studio.
- Label anything "Approved direction", or update official design decisions.
- Generate a large batch before the brief and budget are agreed.
- Treat a beautiful concept as proof the gameplay works, or as scope approval.
