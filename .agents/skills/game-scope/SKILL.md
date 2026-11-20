---
name: Game Scope
description: Decide whether a feature, region, system or art batch belongs in the current scope, or should be cut or deferred. Use when scope is growing, a proposal arrives, a milestone slips, or the vertical slice needs protecting.
---

# Game Scope

The goal is a finished, compelling vertical slice — not the largest feature
list. This skill makes the trade-off explicit instead of silently absorbing
work.

## First

1. Read `harness/project.md` (scope guard, milestone, sources).
2. Read `docs/BACKLOG.md` (out-of-scope list and prototype gate),
   `docs/DEVELOPMENT_PLAN.md` (phases and exit criteria) and the current
   milestone in `docs/MILESTONES.md`.
3. Restate the proposal in one sentence before judging it.

## Workflow

1. **Player-facing value.** What does the player do, feel or understand
   differently? If the answer is "more content" or "it would be cool", say so.
2. **Implementation cost.** Which systems, scenes, data, tests, art frames,
   audio and tuning does it touch? What is the smallest version that tests the
   value?
3. **Dependency and risk.** Does it block or unblock the current milestone?
   Does it create a softlock, a new resource, a new engine feature, or a
   permanent choice the player cannot recover from?
4. **Classify**: **keep** (needed for the current gate), **defer** (valuable
   later, not now), **cut** (does not earn its cost). Give the reason.
5. **Recommend** one path and state what it costs if wrong.
6. **Update docs only after owner agreement.** A proposal is not a
   requirement; a backlog item is not a milestone PASS.

## Heuristics

- Prefer the smallest playable loop over breadth.
- Reuse a system before adding one; add data before code.
- If a feature's value can only be judged after building it, propose a spike
  and label it throwaway.
- Every new permanent choice needs a viable fallback path.
- If two features share the same player value, keep the cheaper one.

## Must not

- Approve scope on the owner's behalf.
- Turn a **Proposed** direction into **Confirmed**, or an exploration into a
  requirement.
- Grow the vertical slice to avoid making a decision.
- Delete or rewrite existing design docs to fit a smaller scope.
