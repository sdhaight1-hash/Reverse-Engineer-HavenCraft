# Windows / Godot 4.4 playtest

## Open
Install the standard **Godot 4.4.1** editor, clone/download this repository and open **project.godot**. Run the main scene (F6) or project (F5). No asset imports or extra plugins required. Test in a 1280x720 window; procedural geometry is intentionally simple.

## Controls
- **WASD** move your character across the test area.
- **Right mouse + drag** orbit third-person camera; **wheel** zoom.
- **Left click** place selected piece; **left drag** stamp a rectangle (maximum 12x12).
- **Q** copy the construction piece under cursor.
- **R** rotate the next building element 90 degrees.
- **P** while aiming at a workshop: pause/resume its work order; the task persists even if all workers are unassigned.
- **F1** switch time from 1x to 8x (useful to watch worker production).
- **F5** save the settlement; **F9** load it.
- **1–9** choose first nine palette tools; click other palette buttons or horizontally scroll.
- **Gather** tool: left-click a tree or stone to gain a resource unit and eventually clear the tile.

## First scenario
1. Drag a 2x2 wood floor in the central clearing, then place a wall on one floor tile.
2. Place a **forester** within seven Manhattan tiles of a tree. A villager is assigned automatically.
3. Toggle F1 and observe wood increase and a tree disappear after a finite number of orders.
4. Put a **sawmill** in the central clearing; verify that it converts **1 wood into 5 planks**.
   - Aim at the sawmill, press **P**, let time pass, and verify production pauses. Press **P** again and observe production resume.
5. Gather rocks manually or build a **quarry** near a rock.
6. Build a **farm** for food and then a **home**, which needs 2 planks.
7. Try to place more tiles than your materials allow. None should appear and no materials should be spent.
8. F5 save, restart, F9 load; verify resource counts, buildings, sites and jobs persist.

## Automated checks
The GitHub Actions workflow imports/parses the project and runs the deterministic simulation suite. Without GitHub Actions, Godot's headless script command is:

```powershell
godot --headless --path . --script res://tests/test_settlement.gd
```

## Known prototype limitations
- Completely flat finite 32x32 environment; no island terrain or environment simulation yet.
- NPCs visually move toward workplaces, but transport/pathfinding is not simulated yet.
- All items currently use shared settlement storage, not individual stockpiles.
- Homes increase comfort only at the food-consumption checkpoint. No immigration or plot-star scoring yet.
- No structural support physics and no smart roof shapes.
- No multiplayer, original game assets, or extracted HavenCraft implementation are included.

Please report: Godot editor/parser errors with file+line, visual placement glitches, build-preview mismatch, or any worker blockage that contradicts the status panel.
