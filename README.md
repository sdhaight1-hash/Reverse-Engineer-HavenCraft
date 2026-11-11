# Reverse Haven

An **independent, clean-room** third-person settlement-building game prototype inspired by Dionic Software's publicly documented HavenCraft game systems.

> This is not official HavenCraft, its source code, a licensed port, or an asset extraction. HavenCraft and its proprietary assets belong to their respective creators. All shipped geometry and game code here are newly created placeholders and implementations.

## Run the prototype

1. Install [Godot 4.4.1](https://godotengine.org/download/).
2. Clone this repository (checkout `work/vertical-slice-01` until PR #1 is merged), or download that branch as ZIP.
3. Open `project.godot` in Godot and press **F5**.

The game has a third-person camera, a 32x32 construction grid, trees/rocks, finite materials, 3 working NPCs, a rudimentary production economy, and save/load. **No external game assets or plugins required.**

**Controls:** WASD move, right-mouse orbit, wheel zoom, left click/drag build, Q pipette, R rotate, F1 accelerate, F5 save, F9 load. See [complete playtest and limitations](docs/PLAYTEST.md).

## Development and validation

- [PR #1: First vertical slice](https://github.com/sdhaight1-hash/Reverse-Engineer-HavenCraft/pull/1)
- [Milestone roadmap and design evidence](docs/ROADMAP.md)
- [Automated simulation tests](tests/test_settlement.gd)
- [Godot CI workflow](.github/workflows/godot-checks.yml)

CI imports the Godot scene, runs **43 deterministic model checks**, and performs a short headless boot of the game. It does **not** replace a human visual/playability assessment.

## What the REA reference actually provides

[morluto/rea](https://github.com/morluto/rea) is a separate reverse-engineering toolkit for binaries, applications, runtime observations, and websites. It does **not** contain HavenCraft's code. No HavenCraft executable was available in this workspace for binary analysis. The [official Steam demo](https://store.steampowered.com/app/5260550/HavenCraft_Demo/) could be a source for future authorized behavior analysis.

The current implementation is a fresh Godot 4 system designed from official descriptions of grid building, workshop workers, supply chains, villager amenities, and plot customization. References:

- [HavenCraft official site](https://havencraft.dionicsoftware.com/)
- [Building and dragging](https://havencraft.dionicsoftware.com/devlog/3/)
- [NPC management](https://havencraft.dionicsoftware.com/devlog/5/)
- [Plot upgrades](https://havencraft.dionicsoftware.com/devlog/10/)
