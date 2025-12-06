# Elyra - Implementation Spec

## Core Concept
2-4 player competitive territory control game in 3D using ThreeJS (through Threlte). Players capture tiles by moving over them or shooting beams. Most territory controlled when 2-minute timer ends wins.

## Technical Specs
- **Grid:** 100x100 tiles
- **Match Length:** 2 minutes
- **Controls:** WASD movement, mouse camera control, click to shoot
- **Players:** 2-4, each with unique color

## Game Mechanics

### Tile Capturing
- **Glow Radius:** Players capture tiles within 1.5 tile radius automatically as they move
- **Beam Shooting:** Click to fire beam that captures all tiles it passes through
  - Costs 25 energy per shot
  - Energy bar: max 100, regenerates at 10/second
  - Beam speed: ~50 tiles/second
  - Beam width: 0.3 tiles
  - Visual: colored line with slight glow, fades after 0.5s

### Tile Types
- **Walkable:** Default, can be captured
- **Hole:** Blocks movement, beams pass through (don't render or render dark)
- **Wall:** Blocks movement AND beams
- **Mirror Wall:** Wall that reflects beams at 90° (45° diagonal mirrors facing NE-SW or NW-SE)
- **Generator Tile:** Walkable tile that grants +3 coins/second while controlled (pulsing neutral gold glow)
- **All tiles start neutral** (no decay, can be recaptured infinitely)

## Economy System

### Coins (for buying power-ups)
- **Passive:** +1 coin/second per player
- **Generator Tiles:** +3 coins/second while controlled (8-12 placed on map)
- **Coin Drops:** Spawn at random walkable tiles with pre-spawn telegraph:
  - Common (bronze): 10 coins, flashes yellow 3 sec before spawn (every 30-60s)
  - Rare (silver): 25 coins, flashes blue 5 sec before spawn
  - Epic (gold): 50 coins, flashes purple 7 sec before spawn
- **Starting coins:** 0
- **Multi-player pickup rule:** If multiple players on coin drop simultaneously, item can't be collected until one steps off

## Power-Up Market (Left Side UI)

### Stackable Upgrades
- **Move Speed:** 15 coins, +10% speed (max 3 stacks)
- **Glow Radius:** 20 coins, +0.5 tile radius (max 3 stacks)
- **Energy Capacity:** 20 coins, +50 max energy (max 2 stacks)

### One-Time Abilities
- **Multi-Shot:** 40 coins, fire beams in 4 cardinal directions simultaneously
- **Piercing Beam:** 35 coins, beam passes through first wall/mirror, stops on second
- **Beam Speed:** 30 coins, beams travel 2x faster

## Map Generation (100x100)
1. Start all walkable
2. Place 8-12 generator tiles (minimum 15 tiles apart)
3. Create 15-25 wall clusters (3-10 connected wall tiles each)
4. Ensure all walkable areas connected via flood fill pathfinding check
5. Place 5-10 holes randomly
6. Convert 30% of wall tiles to mirror walls (45° angle, random facing)
7. Place 4 player spawns in corners/edges with 5x5 clear area around each

## UI Layout
```
Left Side:
- Market menu with 6 power-ups (show price, owned status)
- Energy bar: [====] X/100
- Coins: 💰 X

Top Right:
- Timer: M:SS
- Territory %: 
  Red: X%
  Blue: X%
  Green: X%
  Yellow: X%
```

## Performance Requirements
**CRITICAL:** Use InstancedMesh for tiles to avoid 10,000 draw calls:
- One instanced mesh for ground tiles (10,000 instances)
- Separate instanced meshes for walls, mirrors
- Update tile colors via `setColorAt()` and `instanceColor.needsUpdate = true`
- Use object pooling for beams (~50 pre-created)

## Implementation Phases
1. **Core:** Grid rendering, player movement (WASD + mouse), glow radius capturing
2. **Combat:** Beam shooting, tile capturing via beams
3. **Obstacles:** Walls (block all), holes (block movement), mirrors (reflect beams)
4. **Economy:** Passive coins, generator tiles, coin drops with telegraphs, market UI
5. **Power-ups:** All 6 upgrades functional
6. **Win Condition:** Timer, territory % display, game end screen

## Networking Note
This spec assumes local multiplayer or you'll handle networking separately. If multiplayer, send tile change deltas only, not full grid state.