# Elyra Game Architecture - AI Tech Notes

## Stack Overview

- **Backend**: Elixir + Phoenix Framework
- **Realtime Communication**: Phoenix Channels over WebSockets
- **Message Format**: Protocol Buffers (Protobuf)
- **Persistent Storage**: PostgreSQL (via Ecto)
- **Game State Management**: In-memory using GenServer processes

## Architecture Principles

### Data Storage Strategy

**Two-tier approach:**

- **PostgreSQL**: User accounts, authentication, player stats, match history, unlocks/progression
- **In-Memory (GenServer)**: Active game state during matches - positions, scores, territory control, etc.
- **Persistence Flow**: Only write to Postgres when matches end or at periodic checkpoints

### Process Structure

```
Supervisor (Game.MatchSupervicer)
├── GenServer (Match 1) - handles game logic for one match
├── GenServer (Match 2) - handles game logic for another match
└── GenServer (Match N)

Matchmaking.Server (GenServer) - pairs players into matches
```

**Each Match GenServer:**

- Holds authoritative game state (player positions, ink coverage, scores)
- Runs game loop at 60 Hz
- Validates all player inputs (server-authoritative to prevent cheating)
- Broadcasts updates to connected players via PubSub

### Communication Flow

1. Client connects via WebSocket → Phoenix Channel
2. Player joins/creates match → assigned to a Match GenServer
3. Client sends input (movement, shooting) → Match GenServer
4. GenServer validates & updates game state
5. GenServer broadcasts state updates → all players in match
6. Match ends → GenServer persists results to Postgres → process terminates

---

## Protocol Buffers Setup

### Why Protobuf

- **Type Safety**: Shared schema between client and server
- **Compact**: 3-10x smaller than JSON for game state
- **Fast**: Efficient serialization/deserialization
- **Versioning**: Built-in backwards compatibility
- **Multi-language**: Generate code for Elixir, JavaScript, TypeScript, etc.

### Elixir Libraries

- **Server**: `protobuf` + `google_protos` packages
- Generate Elixir modules from `.proto` files

### Client Libraries

- **JavaScript/TypeScript**: `protobufjs` or `google-protobuf`
- **Unity/C#**: Built-in protobuf support
- **Other engines**: Official protobuf compilers available

### Message Schema Location

```
/priv/proto/
├── game_messages.proto     # Core game messages
├── player_input.proto      # Client input messages
└── game_state.proto        # Server state messages
```

---

## Realtime Game Loop Design

### Server Tick Rate: 60 Hz

- Game loop runs every ~16.67ms
- Provides smooth, responsive gameplay for precise combat
- Each tick: process inputs → update physics → broadcast state

### Network Protocol Definition

**Client → Server (Input Updates at 60 Hz)**

```protobuf
// player_input.proto
syntax = "proto3";

package game;

message PlayerInput {
  uint64 client_timestamp = 1;
  InputState input_state = 2;
  float aim_direction = 3;  // degrees
  bool shooting = 4;
}

message InputState {
  bool w = 1;
  bool a = 2;
  bool s = 3;
  bool d = 4;
  bool jump = 5;
  bool special = 6;
}
```

**Server → Client (State Snapshots at 60 Hz)**

```protobuf
// game_state.proto
syntax = "proto3";

package game;

message GameState {
  uint64 tick = 1;
  uint64 server_timestamp = 2;
  repeated PlayerState players = 3;
  repeated InkSplat ink_updates = 4;
  ScoreState scores = 5;
}

message PlayerState {
  uint32 player_id = 1;
  float x = 2;
  float y = 3;
  float rotation = 4;  // degrees
  bool shooting = 5;
  uint32 health = 6;
  PlayerTeam team = 7;
}

message InkSplat {
  float x = 1;
  float y = 2;
  float radius = 3;
  PlayerTeam team = 4;
}

message ScoreState {
  uint32 team_a_coverage = 1;  // percentage
  uint32 team_b_coverage = 2;
  uint32 time_remaining = 3;   // seconds
}

enum PlayerTeam {
  TEAM_UNKNOWN = 0;
  TEAM_A = 1;
  TEAM_B = 2;
}
```

**Match Lifecycle Messages**

```protobuf
// game_messages.proto
syntax = "proto3";

package game;

message JoinMatchRequest {
  string player_id = 1;
  string match_id = 2;  // empty for matchmaking
}

message JoinMatchResponse {
  bool success = 1;
  string match_id = 2;
  uint32 assigned_player_id = 3;
  PlayerTeam assigned_team = 4;
  string error_message = 5;
}

message MatchStarted {
  repeated PlayerInfo players = 1;
  MapInfo map = 2;
  uint32 duration_seconds = 3;
}

message MatchEnded {
  PlayerTeam winning_team = 1;
  ScoreState final_scores = 2;
  repeated PlayerStats player_stats = 3;
}

message PlayerInfo {
  uint32 player_id = 1;
  string username = 2;
  PlayerTeam team = 3;
}

message PlayerStats {
  uint32 player_id = 1;
  uint32 ink_coverage = 2;
  uint32 eliminations = 3;
  uint32 deaths = 4;
}

message MapInfo {
  string map_id = 1;
  string map_name = 2;
}
```

### Message Size Estimates

With Protobuf (binary encoding):

- `PlayerInput`: ~15-20 bytes
- `PlayerState`: ~25-30 bytes per player
- `GameState` (6 players): ~200-250 bytes
- At 60 Hz: ~12-15 KB/s per client (excellent!)

Compare to JSON: ~40-50 KB/s for same data

---

## Implementation Details

### Phoenix Channel Message Handling

```elixir
# lib/my_game_web/channels/game_channel.ex
defmodule MyGameWeb.GameChannel do
  use Phoenix.Channel
  alias Game.Proto.{PlayerInput, GameState}

  def join("game:" <> match_id, _params, socket) do
    # Handle match joining
    {:ok, assign(socket, :match_id, match_id)}
  end

  # Receive binary protobuf messages
  def handle_in("input", {:binary, payload}, socket) do
    case PlayerInput.decode(payload) do
      {:ok, input} ->
        match_id = socket.assigns.match_id
        Game.MatchServer.process_input(match_id, socket.assigns.player_id, input)
        {:noreply, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: "Invalid input"}}, socket}
    end
  end
end
```

### Match GenServer Broadcasting

```elixir
# lib/my_game/match_server.ex
defmodule Game.MatchServer do
  use GenServer
  alias Game.Proto.GameState

  # Game loop - runs at 60 Hz
  def handle_info(:tick, state) do
    # Update game state
    new_state = update_game_state(state)

    # Encode to protobuf binary
    game_state_msg = build_game_state_message(new_state)
    {:ok, payload} = GameState.encode(game_state_msg)

    # Broadcast binary to all players
    Phoenix.PubSub.broadcast(
      MyGame.PubSub,
      "game:#{state.match_id}",
      {:game_state, payload}
    )

    # Schedule next tick
    Process.send_after(self(), :tick, 16)  # ~60 Hz

    {:noreply, new_state}
  end
end
```

### Client-Side Handling (TypeScript/JavaScript)

```typescript
// client/src/proto/game.ts
import { PlayerInput, GameState } from "./generated/game_pb";

class GameClient {
  private channel: Phoenix.Channel;

  sendInput(keys: KeyState, aimDirection: number, shooting: boolean) {
    const input = new PlayerInput();
    input.setClientTimestamp(Date.now());
    input.setAimDirection(aimDirection);
    input.setShooting(shooting);

    const inputState = new InputState();
    inputState.setW(keys.w);
    inputState.setA(keys.a);
    inputState.setS(keys.s);
    inputState.setD(keys.d);
    input.setInputState(inputState);

    // Send binary protobuf
    const binary = input.serializeBinary();
    this.channel.push("input", binary);
  }

  onGameState(callback: (state: GameState) => void) {
    this.channel.on("game_state", (payload: ArrayBuffer) => {
      const state = GameState.deserializeBinary(new Uint8Array(payload));
      callback(state);
    });
  }
}
```

---

## State Synchronization Strategy

**Approach: Full State Snapshots**

- Send complete game state every tick
- Type-safe with Protobuf schemas
- Compact binary encoding (~200-250 bytes for 6 players)
- At 60 Hz = ~12-15 KB/s per client (very manageable)

---

## Client-Side Rendering Strategy

We're using **responsive input + server authority + interpolation** (no full prediction).

### Local Player Rendering

1. **Immediate Input Response**: Client immediately updates local player visual position based on WASD input
2. **Server Reconciliation**: When server position arrives, smoothly correct any drift over 2-3 frames
3. **Accept Server as Truth**: Server position is authoritative, client never argues

```typescript
// Pseudocode for local player
onInput(keys: KeyState) {
  // Show immediate visual feedback
  this.localPlayer.updateVisualPosition(keys);

  // Send typed protobuf input to server
  this.gameClient.sendInput(keys, this.aimDirection, this.shooting);
}

onServerUpdate(state: GameState) {
  const serverPlayer = state.getPlayersList()
    .find(p => p.getPlayerId() === this.localPlayerId);

  // Smoothly interpolate to server position
  this.localPlayer.reconcile(serverPlayer, 0.1);
}
```

### Other Players Rendering

1. **Render in the Past**: Display other players ~100ms behind real-time
2. **Interpolate Between Snapshots**: Smoothly animate between received positions
3. **Handle Jitter**: Buffer helps smooth out network inconsistencies

```typescript
// Pseudocode for remote players
onServerUpdate(state: GameState) {
  for (const playerState of state.getPlayersList()) {
    if (playerState.getPlayerId() !== this.localPlayerId) {
      this.remotePlayers[playerState.getPlayerId()]
        .addSnapshot(playerState, state.getServerTimestamp());
    }
  }
}

onRender() {
  const renderTime = Date.now() - 100;  // Render in the past

  for (const player of Object.values(this.remotePlayers)) {
    // Interpolate between two snapshots
    const interpolatedState = player.interpolate(renderTime);
    player.render(interpolatedState);
  }
}
```

### Shooting/Inking

- **Client**: Show ink spray animation immediately (responsive feedback)
- **Server**: Determines what actually got inked (authoritative, prevents cheating)
- **Broadcast**: Ink updates sent as part of typed `GameState` message

### Why This Works

- **<100ms latency**: Feels responsive enough without complex prediction
- **60 Hz updates**: Frequent enough that interpolation looks smooth
- **Immediate visual feedback**: Player sees their input acknowledged instantly
- **Server authority**: Prevents cheating, ensures fair gameplay
- **Type safety**: Protobuf prevents message format errors
- **Compact**: Binary encoding keeps bandwidth low

---

## Performance Considerations

### Server

- Each Match GenServer runs independently (isolated failure)
- 60 Hz × N matches = manageable on modern hardware
- Protobuf encoding/decoding is fast (~microseconds)
- Monitor: CPU per match, message queue lengths
- Scale: Multiple nodes with distributed matches if needed

### Client

- Protobuf deserialization is efficient
- Binary format reduces parsing overhead vs JSON
- Monitor: Frame rate, network bandwidth, input lag

### Network

- Target: <100ms latency for good experience
- Binary Protobuf: ~70% bandwidth savings vs JSON
- WebSocket binary frames (no base64 overhead)
- Graceful degradation: Reduce tick rate for high-latency players if needed
- Consider: Geographic server regions if player base grows

---

## Development Workflow

### Proto File Management

1. Define/update `.proto` files in `/priv/proto/`
2. Run code generation for both server and client:

   ```bash
   # Server (Elixir)
   protoc --elixir_out=lib/my_game/proto priv/proto/*.proto

   # Client (TypeScript)
   protoc --js_out=import_style=commonjs:client/src/proto \
          --ts_out=client/src/proto \
          priv/proto/*.proto
   ```

3. Commit generated code or generate in CI/build pipeline
4. Both teams work with type-safe message objects

### Version Management

- Use Protobuf field numbers carefully (never reuse)
- Add new optional fields (backwards compatible)
- Version your protocol if breaking changes needed
- Consider adding `version` field to messages

### Testing

- Unit test protobuf encoding/decoding
- Integration test with real WebSocket connections
- Use Protobuf text format for readable test fixtures

---

## Implementation Phases

**Phase 1: Core Loop + Protobuf Setup**

- Define `.proto` schemas for all messages
- Set up code generation pipeline
- Basic Match GenServer with 60 Hz tick
- Simple WASD movement physics
- Binary protobuf over Phoenix Channels
- Test with artificial latency

**Phase 2: Polish**

- Add interpolation for remote players
- Tune reconciliation smoothing
- Implement shooting/inking mechanics
- Add match lifecycle (join, start, end)

**Phase 3: Optimize**

- Profile bandwidth usage (should already be good!)
- Monitor encoding/decoding performance
- Add lag compensation if testing shows it's required

**Phase 4: Scale**

- Match supervision and recovery
- Matchmaking service
- Database persistence layer
- Metrics and monitoring

---

## Key Decisions Summary

| Aspect           | Decision                         | Rationale                                          |
| ---------------- | -------------------------------- | -------------------------------------------------- |
| Message Format   | Protocol Buffers                 | Type safety, compact binary, 70% bandwidth savings |
| Tick Rate        | 60 Hz                            | Precise combat requires responsive updates         |
| State Sync       | Full snapshots                   | Simple, adequate with Protobuf compression         |
| Movement Model   | WASD input streaming             | Typical for action games                           |
| Client Strategy  | Responsive input + interpolation | Good feel without prediction complexity            |
| Server Authority | Full                             | Prevents cheating                                  |
| Persistence      | End-of-match                     | Performance during gameplay                        |

---

## Resources

- **Protobuf Docs**: https://protobuf.dev/
- **Elixir Protobuf**: https://hex.pm/packages/protobuf
- **protobuf.js**: https://github.com/protobufjs/protobuf.js
- **Phoenix Channels**: https://hexdocs.pm/phoenix/channels.html

---

## Testing Strategy

1. **Local testing**: Artificial latency (50ms, 100ms, 150ms)
2. **Measure**: Input lag perception, visual smoothness, bandwidth usage
3. **Validate**: Type safety catches message format errors early
4. **Iterate**: Tune interpolation parameters based on feel
5. **Load test**: Multiple concurrent matches with protobuf encoding
