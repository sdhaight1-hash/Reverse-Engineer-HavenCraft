# HavenCraft demo — evidence-based technical reconnaissance
_Date: 2026-11-11. Target: official Windows Steam demo app 5260550 (parent 2481240)._

## Evidence status (do not overclaim)
- **Directly observed, public artifact metadata:** SteamDB lists a Windows Unity demo, with Mono SDK, Burst SDK, Unity Multiplayer Services and URP detected. Depot 5260551 is reported as ~1.94 GiB installed/~749 MiB download, with public build 26045324 dated 2026-10-19. This is SteamDB's detection, **not** local binary validation.
- **Developer-documented behavior:** The linked release notes and devlogs below directly describe gameplay, changes, and some technical architecture, but not complete implementation.
- **Game binary/runtime inspection:** **NOT COMPLETE** at report creation. No demo executable attached/mounted, REA MCP not connected, and local container DNS cannot fetch the Steam demo. A separate opt-in/repeatable GitHub Actions SteamCMD+REA static probe is provided; read its results before upgrading any claim to “binary observed.”
- **Gameplay live observation:** **NOT COMPLETE**. Published footage/docs are not equivalent to personally running the demo. No frame-perfect mechanics, tick rates, navigation rules or save formats have been verified.
- **Clean-room rule:** Do not commit/release game binaries, images, sounds, raw disassembly, decompiled code or Unity asset dumps. Record reproducible behavior/evidence, then implement independent equivalents.

## Source facts and consequences

| Area | Public source evidence | Confidence | Consequence for our original prototype |
| --- | --- | --- | --- |
| Runtime | SteamDB lists Unity Engine, Mono SDK, UnityBurst SDK, UnityURP SDK, UnityMultiplayerServices SDK. | Metadata-detected (not independently validated) | Inspect Unity layout; **do not claim Mono C# game logic** until `Managed/Assembly-CSharp.dll` is actually found. Alternative IL2CPP must be checked. |
| Construction grid | Developer describes grid building; public devlog describes 12 m drag per direction, up to 144 pieces, dragging furniture, terrain-following fields and diagonal stairs/roofs. | Documented, 2025-06 | Our rectangular flat stamping covers only a subset; distinguish line/rectangle/diagonal/height-adaptive brushes. |
| Roof topology | Alpha 6 merges adjacent roofs, adds automatic corners and wall triangles under roofs; limited to 45° roof pieces in initial rollout. | Documented, 2026-09 | Building pieces need typed adjacency and a deterministic mesh resolver, not only independent roof boxes. |
| Work orders | Alpha 6 changed work orders from villager-owned to **plot-owned**. New workers on the same plot pick up existing orders; defaults are active. | Documented, 2026-09 | Our direct villager-to-workstation assignment is the wrong domain boundary. Move order queues into plot state with workers as assignees. |
| Worker transparency | Every task shows availability/blocking, including missing materials, storage and reachability; overhead NPC state updates immediately. | Documented, 2025-07 | Keep explicit blocker UI, extend to path and destination logistics with named cause. |
| Plot upgrades | Plot sign defines use/type and required pieces (beds, counters, benches); number of functional pieces influences capacity. Plot quality depends on size/decoration/materials and star rating impacts work speed or amenities. | Documented, 2025-10 | Add plot areas, furniture validation, occupancy/capacity/rating independent from visual building shells. |
| Logistics | Packling transports stockpile-to-stockpile; Skyling brings requested materials to players from Skyling stations on stockpiles. Supply stands, stockpile filters and chests have plot context. | Documented, 2025-11 and 2026-09 | Global shared inventory in current prototype is a temporary convenience **and materially unlike target**. Need per-container stacks and jobs/reservations/delivery. |
| Reforestation | Stakes remain after cutting and enable replant/grow/cut cycles in forester zone. | Documented, 2025-11 | Replace permanent natural depletion with optional planted/renewable site lifecycle. |
| Movement | Road gives +40% speed to player, villagers and Packlings; villagers pick up multiple inputs for a craft session. | Documented, 2026-09 | Model actual path distances and material hauling; street speed affects path costs, not simply rendering. |
| Needs and services | Food, tools and amenities matter; tavern counters support three villagers in Alpha 6; latest public 6.0.5 patch states villager food selection attempts to balance berries/honey/bread. Happiness reacts to supplies immediately. | Documented, 2026-09/10 | Our pooled-food consumption at an arbitrary periodic checkpoint and basic happiness number are only scaffolding. |
| Production balancing | Alpha 6 changed sawing to **5 planks per wood** and cutting to **6 bricks per stone**. | Documented, 2026-09 | The prototype now uses the documented Alpha 6 ratio of 1 wood -> 5 planks; work duration remains a prototype assumption. |
| Environment | Seasons 5 days long in Alpha 6.0.1, snowfall in winter; the developer mentions dynamic world and pathfinding. | Documented, 2026-09 | Defer environment polish until core economy/plot/logistics match. |
| Performance | Alpha 6.0.1 describes Burst work-order planner off main thread, reachability cache, selective interaction-spot reanalysis, direct batch rendering of item piles/building elements and off-thread indoors checks. | Documented developer architecture claims, not source verified | Prefer compact world data, cached spatial queries and controlled invalidations, no mesh node per item at town scale. |
| Multiplayer | Singleplayer/multiplayer with host-driven dialogues and replicated world tags; save compatible with full game; not proven that any particular network framework is used by core sim. | Documented, 2026-09 | Keep authoritative simulation and stable save schema; avoid implementing replication now. |

## Target game's technical boundary (hypotheses, NOT recovered implementation)
The simplest **independent** architecture consistent with public evidence is:
1. Terrain and construction cells, with build-brush geometry and adjacency-based model resolution.
2. Explicit **Plot** entity (area, type, furnishings, grade, allowed work slots, inventory access).
3. **Container / inventory** entities with ownership, location, capacity, filters.
4. **WorkOrder** records owned by plots with ingredients, output, target stock, priorities, work progress.
5. Agents select jobs from available plot orders via reachability + reservations; jobs consist of gather/deliver/work/deposit steps.
6. Spatial reachability index invalidated only for relevant topology changes; road speed applied as movement cost.
7. Player materials travel via carried inventory and Skyling deliveries, not magically shared stock.
8. Persistence stores plot/order/container/agent state plus stable referenced IDs; all item transfers conservative.

Do **not** infer original data structures, function names, serialization encoding, authoritative rates, or exact navigation algorithms from these developer-facing descriptions.

## Minimal acceptance experiments (require running demo)
1. **Build brush:** flat 1x1/2x2/12x12, invalid intersection, sloped terrain, diagonal stairs and roof; measure piece count, resource debit and orientation.
2. **Work plot:** create carpenter plot; configure order with no worker; add/remove workers; verify order survives and blockers.
3. **Spatial inventory:** put inputs in chest on plot versus chest outside plot; isolate storage; check workers' reachability and “no space”.
4. **Movement:** time worker on road and nearby terrain with same route distance; record times/speeds and confounds.
5. **Renewability:** add planted stakes, deplete and observe growth/harvest lifecycle.
6. **Needs:** vary supply stand food types and tavern coverage; measure happiness update timing.
7. **Persistence:** save/load mid-order and during delivery; check exact inputs/outputs and assigned jobs.
8. **Multiplayer later:** observe host/client changes only after deterministic solo systems pass.

For every experiment log demo version, action sequence, initial state, screenshot/video timestamps, observed vs expected, and repeat count.

## Static binary acquisition and REA probe
The branch includes `.github/workflows/havencraft-demo-recon.yml`. It attempts to acquire the **free demo** through official SteamCMD anonymous login on a GitHub-hosted runner. Anonymous entitlement is **not guaranteed**. If access fails, report the failure; never bypass account/DRM restrictions.

If it succeeds, use REA 6.7.0's read-only `inspect-desktop-application`, and optionally `inspect-managed-artifact` on actual `Assembly-CSharp.dll` only if one exists. Compare candidate Unity Mono vs Unity IL2CPP and save SHA-256 fingerprints, no game content. Static metadata **does not establish runtime behavior**.

A separate hands-on demo playtest on Windows remains essential even with a successful static probe.

## Primary sources
- [Official Steam Demo](https://store.steampowered.com/app/5260550/HavenCraft_Demo/)
- [SteamDB demo metadata & depot](https://steamdb.info/app/5260550/depots/)
- [Devlog #3: Building, grid and dragging](https://havencraft.dionicsoftware.com/devlog/3/)
- [Devlog #5: Worker state and task blockers](https://havencraft.dionicsoftware.com/devlog/5/)
- [Devlog #8: Skylings](https://havencraft.dionicsoftware.com/devlog/8/)
- [Devlog #10: Plot upgrades](https://havencraft.dionicsoftware.com/devlog/10/)
- [Devlog #11: Replanting and logistics](https://havencraft.dionicsoftware.com/devlog/11/)
- [Devlog #18: Work orders, road, roof](https://havencraft.dionicsoftware.com/devlog/18/)
- [Alpha 6.0.1 changelog: detailed mechanics/performance](https://havencraft.dionicsoftware.com/changelog/alpha-6.0.1/)
- [Alpha 6.0.5 changelog: latest 2026-10-19 update](https://havencraft.dionicsoftware.com/changelog/alpha-6.0.5/)
- [REA read-only desktop application inspection docs](https://github.com/morluto/rea/blob/main/docs/desktop-applications.md)
- [REA managed artifact docs](https://github.com/morluto/rea/blob/main/docs/guides/managed/managed-code-analysis.md)
