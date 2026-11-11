# Reverse Haven — milestone roadmap

## Non-goals and evidence
This project is an **independent gameplay-system reimplementation**. No proprietary code or assets are copied. The public website provides design observations, **not** implementation truth. **REA** (morluto/rea) is an optional external reverse-engineering toolkit; it is not the HavenCraft project, does not ship its game sources, and has not analyzed a HavenCraft executable in this milestone.

Evidence levels used in subsequent research:
- **Publicly documented:** directly described by official website or devlog.
- **Observed:** repeatable behavior verified in legal playtests, screenshots, videos or instrumented runs.
- **Hypothesized:** potential internal mechanism (not a claim about HavenCraft source).
- **Original implementation:** the architecture chosen for this independent project.

## Milestone 0 — playable foundation (implemented on work/vertical-slice-01)
- [x] Godot 4.4 3D scene, third-person camera and mouse orbit, WASD navigation.
- [x] Deterministic island-sized 32x32 test grid and finite tree/rock patches.
- [x] Click or rectangle-drag construction with 12x12 limit, layered floor/wall/roof, costs and occupancy checks.
- [x] Pipette (Q), rotation (R), basic procedural buildings, visual placement validity.
- [x] Three autonomous workers; station assignment, blocked-work status and production progress.
- [x] Timber + quarry + farm + sawmill economy; wood to plank dependency.
- [x] Population food consumption, rudimentary morale, warehouse capacity.
- [x] Save/load versioned JSON, time acceleration and automated simulation regression suite.
- [x] Godot CI import, simulation regression checks (63), Python ZIP metadata tests (3), headless scene boot.
- [ ] Human visual/gameplay check on Windows.
- [x] Evidence-driven intermediate step: temporary plot-owned order records, worker-independent persistence, order pause/resume and legacy save migration.
- [ ] True plot-area geometry/furnishing prerequisites and container-based logistics (next milestones).

**Acceptance:** Open the main scene, drag 2x2 floors, place a wall on an existing floor, build a forester near trees, observe wood output and site depletion, build a sawmill, observe plank creation and missing-material blockers; save, relaunch and load the town. The CI suite must pass first.

## Milestone 1 — construction as a coherent building system
- Introduce plots, room boundaries and functional furniture requirements (no assumption about original internal algorithms).
- Foundation/roof support rules, doors, windows, stairs, select/delete, undo.
- Terrain-aware building placement; drag shape handling, no overlapping grid confusion.
- Plot ratings from dimensions, furniture, material quality, amenities.
- Test structural invariants, rapid 144-tile placement and save stability.

## Milestone 2 — villagers, logistics and jobs
- Walkable paths and real navigation, carrying and delivery between local storage.
- Finite forestry, planting, quarry depletion and renewable farm yields.
- Explicit worker assignment and priorities, no-worker, unreachable, storage-full and missing-input explanations.
- Work-order queuing, job interruption, task reservations, transparent worker UI.
- Simulated workers rather than cosmetic waypoint animations.

## Milestone 3 — needs and settlement growth
- Homes/beds and comfort grades; hunger, employment, happiness, migrants.
- Tavern/public services, catchment areas, household consumption and different food types.
- Research chain and unlocks.
- Robust simulation telemetry including production per day and blocked job counts.

## Milestone 4 — advanced systems
- Procedural terrain, natural vegetation regeneration, seasons and climate.
- Automation, mechanized production, dedicated inventory logistics.
- Town-scale performance and multi-threadable simulation boundary.
- Multiplayer only after determinism, serialization and authoritative simulation are validated.

## Reverse-engineering plan for later evidence
The Steam demo is available for Windows. If its **installed executable/data directory** is provided for lawful local examination, use the separate REA project as a guide to inspect file type, Unity/other runtime, data boundaries, save formats and observable behavior. Record exact builds and evidence without assuming decompiled output corresponds to original source. Do not redistribute extracted art, audio, code or trademarked branding.

## Primary references
- https://havencraft.dionicsoftware.com/
- https://havencraft.dionicsoftware.com/devlog/3/ (grid and 12x12 drag)
- https://havencraft.dionicsoftware.com/devlog/5/ (worker-state transparency)
- https://havencraft.dionicsoftware.com/devlog/10/ (plot upgrades)
- https://havencraft.dionicsoftware.com/devlog/20/ (Steam demo)
- https://github.com/morluto/rea (optional separate REA toolkit)


## Evidence update (2026-11-11)
The [HavenCraft demo reconnaissance report](research/havencraft-demo-evidence-2026-11-11.md) compared the official Alpha 6 documentation against the independent prototype. It confirmed the target's plot-owned work orders, real storage/logistics and documented sawmill conversion of **1 wood into 5 planks**. The current build has adopted the latter conversion and an initial workshop-as-plot order lifecycle, but still uses shared inventory and cosmetic NPC movement.

**Binary analysis is blocked**: the official SteamCMD anonymous download failed with exit code 8 and acquired zero files. See [local REA runbook](research/LOCAL_REA_RUNBOOK.md); no source code or runtime mechanisms have been recovered. The GitHub Steam workflow is manual-only pending lawful installation access.
