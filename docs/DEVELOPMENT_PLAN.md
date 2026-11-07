# GENESIS — Development Plan v0.1

**Working title:** GENESIS — The Journey Before Life  
**Genre:** 2D side-scrolling Action Metroidvania  
**Development model:** Solo + AI  
**Target platform:** PC / Steam first; consoles may follow  
**Initial scope target:** 4–6 hours  
**Status:** Initial plan; validate through prototyping

---

## 1. Product vision

GENESIS follows the development of a human life inside the mother's womb, beginning as a single fertilized cell and ending with birth.

The player does not merely watch biological development. They experience it through exploration, absorption, survival, combat, adaptation and evolution.

**Core emotional message:** Parents — the love, effort and sacrifice that make a new life possible.

### Design pillars

1. **Evolution** — the body is the player's progression system and identity.
2. **Combat** — combat develops alongside biological capabilities.
3. **Science** — a fantasy world inspired by biology, not a strict simulation.
4. **Emotion** — the player gradually discovers the meaning of the journey.

### Design principles

- Evolution is permanent. Adaptation is flexible.
- The body is the weapon, movement system and key to exploration.
- New body parts should meaningfully affect combat, traversal or interaction.
- Exploration rewards curiosity.
- Biological inspiration should support fantasy and gameplay.
- The mother is a nurturing/protective presence, not the primary antagonist.

---

## 2. Decision status

| Topic | Status | Current direction |
|---|---|---|
| 2D side-scrolling Action Metroidvania | Confirmed | Core genre |
| Evolution, Combat, Science | Confirmed | Main pillars |
| Parents as emotional message | Confirmed | Environmental storytelling |
| PC first | Confirmed | Steam target |
| Solo + AI | Confirmed | No fixed deadline |
| Godot | Proposed | Prototype first; Unity remains an alternative |
| Frame-by-frame 2D art | Confirmed direction | Validate production cost |
| 4–6 hour initial scope | Proposed | MVP target |
| 8–12 hour expansion | Open | Only if core loop and production justify it |
| 7–9 developmental stages | Proposed / Risk | Consolidate if stages do not add distinct gameplay |
| 4–5 major evolution branches | Proposed | Start with fewer in prototype |
| English first | Confirmed | Architect localization early |
| Steam demo | Current preference: no demo | Revisit near release |
| Price | Open | Decide based on quality and market positioning |
| Commercial commitment | Open | Passion project and long-term indie brand; commercial viability was also previously named as a priority |

Do not treat every brainstorm answer as a mandatory feature. The prototype and vertical slice are allowed to simplify or reject systems that do not improve the game.

---

## 3. Development strategy

**Prove the gameplay → prove evolution → prove the emotional experience → expand the world → polish and release.**

Do not build all developmental stages, evolution branches, enemies or animation sets before validating the core loop.

### Phase 0 — Foundation & pre-production

**Goal:** Turn the interview results into a coherent, buildable design.

Deliverables:
- Game Design Foundation
- Core gameplay loop specification
- Evolution system specification
- World and stage structure
- Art direction reference / Art Bible
- Technical architecture proposal
- Initial production backlog
- Risk register

Exit criteria:
- Core loop is defined.
- Initial evolution path is defined.
- MVP scope is agreed.
- Major open decisions are explicitly recorded.

### Phase 1 — Core prototype

**Goal:** Prove that controlling the early biological form is fun.

Implement:
- Basic 2D movement
- Swimming and crawling
- Surface gripping
- Collision and physics
- Absorption
- One resource type
- One neutral organism
- One hostile organism
- Basic survival / damage
- Camera and a small test environment

Exit criteria:
- Movement feels responsive.
- Absorption is understandable and satisfying.
- Enemy interaction works.
- A small playable area can be completed without external instructions.

Do not build yet: a full inventory, complex evolution tree, multiple regions or elaborate cinematics.

### Phase 2 — Evolution & combat prototype

**Goal:** Prove GENESIS's defining mechanic.

Implement:
- Biological resource collection
- Evolution requirements
- One evolution zone
- One major body transformation
- One offensive body part
- One biological special ability
- Basic energy management
- One boss encounter
- Evolution animation and visual feedback

Exit criteria:
- Evolution visibly changes the character.
- New body parts create meaningful gameplay differences.
- The player feels progression from vulnerable to capable.
- Combat and exploration interact with evolution.

### Phase 3 — Vertical slice

**Goal:** Produce one polished, representative section of the final game.

Suggested content:
- One complete biological region
- One distinct environment identity
- One interconnected exploration route
- One main objective and optional secrets
- Two or three enemy types
- One memorable boss
- One safe biological shelter / checkpoint
- Two evolution choices or meaningful build variations
- Environmental storytelling
- Representative music, sound and visual effects

Exit criteria:
- The slice feels like a real game, not a technology demo.
- Exploration, absorption, evolution and combat form a satisfying loop.
- Art direction is consistent.
- Performance is acceptable on target PC.
- Production effort is understood well enough to estimate the rest of the game.

**Decision gate:** If the slice is not fun, revise the core loop before expanding.

### Phase 4 — Full production

**Goal:** Build the complete game using validated systems.

Implement:
- Main interconnected world
- Developmental stages and milestone transitions
- Evolution branches
- Enemy and boss roster
- Traversal abilities
- Biological interaction puzzles
- Secrets and optional exploration
- Checkpoints and progression
- Narrative discoveries
- Soundtrack and environmental audio

Scope guidelines:
- Start with fewer, higher-quality regions.
- Add stages only when they introduce meaningful gameplay.
- Reuse systems intelligently without making regions feel identical.
- Target 4–6 hours before considering expansion to 8–12 hours.

### Phase 5 — Alpha / content complete

**Goal:** Complete the entire playable journey.

Deliverables:
- All required regions
- Main progression path
- Required bosses
- Essential evolution systems
- Complete ending and birth sequence
- Main narrative and environmental storytelling

Exit criteria:
- The game can be completed from beginning to end.
- No critical progression blockers.
- All major gameplay systems are implemented.

### Phase 6 — Beta, polish & release

**Goal:** Turn the complete game into a polished product.

Tasks:
- Bug fixing
- Balance and difficulty tuning
- Performance optimization
- Animation and VFX polish
- Audio mixing
- UI and accessibility improvements
- Localization
- Steam store assets and release materials
- QA and compatibility testing

Release gate:
- No critical bugs or progression softlocks.
- Stable performance.
- Complete player-facing experience.
- Release scope and pricing decision approved.

---

## 4. Core gameplay loop

**Explore → Absorb → Evolve → Adapt → Overcome → Explore further**

1. Explore a biological environment.
2. Discover organisms, resources and secrets.
3. Absorb biological materials through interaction or combat.
4. Fulfil evolution requirements.
5. Transform at a special evolution zone.
6. Gain combat, traversal or environmental abilities.
7. Reach previously inaccessible areas.
8. Face stronger challenges.

### Initial resource model

| Resource | Primary purpose |
|---|---|
| Nutrition | General development |
| Calcium / minerals | Structural body parts |
| Energy | Special abilities |
| Protein / organic matter | Tissues and organs |
| Genetic material | Traits and evolution branches |

**Validation requirement:** Do not implement five independent resource meters until each has a distinct gameplay purpose. Consider a simpler internal resource model with clear visual representations.

---

## 5. Evolution system

### Proposed structure

- 4–5 major evolution branches.
- Evolution choices are permanent.
- Acquired body parts remain available.
- Equipped parts have capacity limits.
- Capacity expands through progression.
- Body configuration determines combat, movement and interactions.

### Safety requirements

Permanent choices must not:
- Trap the player in an impossible build.
- Prevent mandatory progression.
- Make a required boss practically unbeatable.
- Require a complete restart to recover from a poor choice.

Allow adaptation through equipment combinations and alternative viable paths.

---

## 6. World & narrative

### World structure

One interconnected fantasy-biological world divided into major regions.

Each region should provide:
- A unique visual identity.
- A distinct gameplay challenge.
- New organisms and environmental interactions.
- Evolution-related opportunities.
- Optional secrets and narrative discoveries.

### Narrative delivery

Prioritize environmental storytelling:
- Memories and visual fragments.
- Objects and traces from the outside world.
- Heartbeat and maternal presence at important moments.
- Rare details connecting the father to the story.
- Gradual discovery of the true setting.

### Ending

The final stage should be playable. Birth is the culmination of the player's journey, followed by a cinematic ending.

Emotional target: happiness mixed with a little sadness — the journey inside the womb ends because a new life is beginning.

---

## 7. Technical & asset strategy

### Initial technical direction

- Engine: Godot prototype; Unity remains an alternative.
- Camera: 2D HD side-scrolling.
- Art: 2D frame-by-frame direction.
- Animation: evaluate modular animation and reusable components to control production cost.
- Localization: English first, but design text systems for additional languages from the beginning.
- AI: assist with concept art, references, code, audio exploration, testing and production support.

### Technical prototype requirements

Validate:
- Player controller and physics
- Character state machine
- Animation state management
- Combat and hit detection
- Enemy AI
- Evolution data model
- Resource system
- Save/load and checkpoints
- Camera and world transitions

Avoid complex infrastructure before a gameplay requirement exists.

---

## 8. Scope & risk register

| Risk | Mitigation |
|---|---|
| Too many developmental stages | Consolidate stages if gameplay differences are weak |
| Frame-by-frame animation workload | Reuse animation foundations; prioritize milestone animations |
| Too many evolution branches | Start with one or two branches in prototype |
| Resource system complexity | Validate distinct resource purposes before implementing all types |
| Permanent evolution softlocks | Ensure viable progression across builds |
| AI-generated art inconsistency | Establish an Art Bible and review every asset |
| Overengineering | Build only what the current milestone needs |
| Solo development burnout | Use milestone-based progress, no artificial deadline |

---

## 9. Project governance

Every milestone must have:
- A clear objective.
- A bounded task list.
- Acceptance criteria.
- A playable or reviewable output.
- A decision: **PASS**, **REVISE** or **BLOCKED**.

A failed test is a reason to investigate and recover, not automatically a reason to abandon the milestone.

Keep decisions classified as:
- **Confirmed** — explicitly selected by the user.
- **Proposed** — a recommended direction, not yet locked.
- **Open** — needs a future decision.
- **Risk** — may threaten quality, feasibility or progression.

---

## 10. Immediate next step

Start Phase 0 and prepare the first playable prototype specification.

The first question to prove:

*Is it fun to be a tiny living organism, explore, absorb, survive and evolve into something stronger?*

If yes, GENESIS has a foundation worth expanding.
