KTNE Bomb Addon (starter)
=========================

What it does
------------
- Adds a spawnable SENT: "KTNE Bomb" under the Minigames category.
- Two players use the bomb to join.
- First player becomes the Panel player.
- Second player becomes the Manual player.
- Once both are joined, the bomb auto-starts.
- Panel player gets the bomb interaction UI.
- Manual player gets the instruction/manual UI.
- Includes two starter modules:
  1) Wires
  2) Keypad

Install
-------
Put the folder `ktne_bomb_addon` into:
  garrysmod/addons/

Then restart the server or map.

Spawn
-----
Open spawn menu -> Entities -> Minigames -> KTNE Bomb

How to play
-----------
1. Spawn the bomb.
2. Player A presses USE on it to join as Panel.
3. Player B presses USE on it to join as Manual.
4. The game starts automatically.
5. Panel player manipulates bomb modules.
6. Manual player reads instructions based on the current bomb state.
7. Solve all modules before time runs out or before 3 strikes.

Notes
-----
- This is a clean foundation/starter, not a full clone of Keep Talking and Nobody Explodes.
- It is intentionally built so you can add more modules in `init.lua` and reflect them in `cl_init.lua`.
- If one of the two players disconnects during a round, the bomb resets.

Ideas for next upgrades
-----------------------
- Simon Says module
- Memory module
- Maze module
- Better bomb model and custom sounds
- Spectator UI
- Role reassignment / leave button
- Per-round seed / difficulty selection
- Workshop icon and thumbnail


Solo testing
------------
- Also adds a spawnable SENT: "KTNE Bomb (Solo Test)" under Minigames.
- One player uses the bomb and immediately gets a window with both the Bomb Panel and Manual tabs.
- This is meant for local testing and debugging module logic without needing a second player.
