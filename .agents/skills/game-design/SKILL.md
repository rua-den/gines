---
name: Game Design
description: Design or change a game mechanic, region, evolution branch, boss, progression rule or scope decision, or decide whether an idea is worth building. Produces a decision-ready design doc with explicit Confirmed/Proposed/Open/Risk statuses and non-goals. Use before implementing any new game system.
---

# Game Design

Turn an idea into a design the project owner can approve or reject — not a
feature list and not an implementation.

## First

1. Read `harness/project.md` for the active project's genre, pillars, scope
   guard and sources. If it is missing, ask for the project facts; do not
   assume an engine, genre or milestone.
2. Read the existing design sources the profile names. Search for the topic
   before proposing anything; a decision may already exist.
3. If the request is non-trivial, load the `brainstorming` skill and run it
   before writing. Ask about intent and constraints; explore before asking.

## Workflow

1. **Name the problem in player terms.** What does the player do, feel or
   decide differently if this exists? "More content" is not a problem.
2. **Check the current state.** What exists in the build today? Which
   milestone, scene, script, data resource or doc already touches it?
3. **Lay out 2–3 real approaches.** For each: what the player gets, what it
   costs to build for a solo developer, and what it rules out. Drop weak
   options and say why. Recommend one.
4. **Write the design** using `harness/templates/design-brief.md` into
   `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`.
5. **Label every decision**: **Confirmed** (owner said it), **Proposed** (your
   recommendation), **Open** (needs a decision), **Risk** (may threaten
   quality, feasibility or progression). Never upgrade a status on your own.
6. **State non-goals and anti-goals.** What this deliberately will not do, and
   what would make it a failure even if it technically works.
7. **Protect progression.** Permanent evolution choices must not softlock
   required content, make a required boss practically unbeatable, or force a
   restart. Name the fallback path.
8. **Get approval before building.** The owner approves the design; then hand
   off to the `writing-plans` skill. Do not implement inside this skill.

## Output contract

The design doc must let a builder who never spoke to the owner plan the work:
intent and why, goals, non-goals, anti-goals, constraints, the approaches and
the chosen one, the decisions by status, acceptance criteria, and open risks.

## Must not

- Invent owner approval, or present your recommendation as **Confirmed**.
- Promote a Muse exploration into an approved direction.
- Copy whole sections of existing docs instead of pointing at them.
- Expand scope because a design doc makes it easy to describe.
- Skip the playable/observable acceptance criteria.
