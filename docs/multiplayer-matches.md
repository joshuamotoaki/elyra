# Multiplayer Match System

This document explains the real-time multiplayer match system implemented in Elyra.

## Overview

The match system uses:

- **Phoenix Channels** for real-time WebSocket communication
- **GenServer** for server-authoritative game state
- **DynamicSupervisor** for managing match processes
- **Registry** for process discovery
- **Phoenix PubSub** for broadcasting events

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              FRONTEND                                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   ┌──────────────┐     ┌──────────────┐     ┌──────────────────────────┐   │
│   │ Lobby Page   │     │ Match Page   │     │   match.svelte.ts        │   │
│   │              │     │              │     │   (Reactive Store)       │   │
│   │ - List games │     │ - Waiting    │     │                          │   │
│   │ - Create     │     │ - Playing    │     │   $state: players,       │   │
│   │ - Join       │     │ - Results    │     │           grid, status   │   │
│   └──────┬───────┘     └──────┬───────┘     └────────────┬─────────────┘   │
│          │                    │                          │                  │
│          │ REST               │ Events                   │                  │
│          ▼                    ▼                          ▼                  │
│   ┌──────────────┐     ┌──────────────────────────────────────────────┐    │
│   │MatchService  │     │              SocketService                   │    │
│   │ (REST API)   │     │              (WebSocket)                     │    │
│   └──────┬───────┘     └──────────────────┬───────────────────────────┘    │
│          │                                │                                 │
└──────────┼────────────────────────────────┼─────────────────────────────────┘
           │                                │
           │ HTTP                           │ WebSocket
           ▼                                ▼
┌──────────┴────────────────────────────────┴─────────────────────────────────┐
│                              BACKEND                                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   ┌──────────────┐                 ┌──────────────────────────────────┐     │
│   │ Match        │                 │         UserSocket               │     │
│   │ Controller   │                 │         (JWT Auth)               │     │
│   │              │                 └───────────────┬──────────────────┘     │
│   │ - index      │                                 │                        │
│   │ - create     │                                 ▼                        │
│   │ - show       │                 ┌──────────────────────────────────┐     │
│   │ - join       │                 │        MatchChannel              │     │
│   └──────┬───────┘                 │        (match:*)                 │     │
│          │                         │                                  │     │
│          │                         │  - join (subscribe to match)    │     │
│          ▼                         │  - handle_in: start_game        │     │
│   ┌──────────────┐                 │  - handle_in: click_cell        │     │
│   │   Matches    │                 └───────────────┬──────────────────┘     │
│   │   Context    │                                 │                        │
│   │              │                                 │ calls                  │
│   │ - create     │                                 ▼                        │
│   │ - get        │                 ┌──────────────────────────────────┐     │
│   │ - list       │                 │         MatchServer              │     │
│   │ - add_player │◄────────────────│         (GenServer)              │     │
│   │ - finish     │                 │                                  │     │
│   └──────┬───────┘                 │  State:                         │     │
│          │                         │  - players (map)                │     │
│          ▼                         │  - grid (map)                   │     │
│   ┌──────────────┐                 │  - status                       │     │
│   │   Database   │                 │  - time_remaining               │     │
│   │              │                 │                                  │     │
│   │ - matches    │                 │  Actions:                       │     │
│   │ - match_     │                 │  - join/leave                   │     │
│   │   players    │                 │  - start_game                   │     │
│   └──────────────┘                 │  - click_cell                   │     │
│                                    │  - tick (timer)                 │     │
│                                    └───────────────┬──────────────────┘     │
│                                                    │                        │
│                                                    │ broadcasts via         │
│                                                    ▼                        │
│                                    ┌──────────────────────────────────┐     │
│                                    │         Phoenix.PubSub           │     │
│                                    │                                  │     │
│                                    │  Topics: "match:{id}"           │     │
│                                    └──────────────────────────────────┘     │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

## Game Flow

### 1. Create Match

```
┌─────────┐         ┌─────────┐         ┌─────────┐         ┌─────────┐
│ Frontend│         │ REST API│         │ Context │         │GenServer│
└────┬────┘         └────┬────┘         └────┬────┘         └────┬────┘
     │                   │                   │                   │
     │ POST /api/matches │                   │                   │
     │──────────────────>│                   │                   │
     │                   │                   │                   │
     │                   │ create_match()    │                   │
     │                   │──────────────────>│                   │
     │                   │                   │                   │
     │                   │                   │ INSERT match      │
     │                   │                   │ (code: "ABC123")  │
     │                   │                   │                   │
     │                   │                   │ start_match()     │
     │                   │                   │──────────────────>│
     │                   │                   │                   │
     │                   │                   │              GenServer
     │                   │                   │              started with
     │                   │                   │              initial state
     │                   │                   │                   │
     │   {id, code}      │                   │                   │
     │<──────────────────│                   │                   │
     │                   │                   │                   │
     │ goto /match/{id}  │                   │                   │
     │                   │                   │                   │
```

### 2. Join Match via WebSocket

```
┌─────────┐         ┌─────────┐         ┌─────────┐         ┌─────────┐
│ Frontend│         │ Socket  │         │ Channel │         │GenServer│
└────┬────┘         └────┬────┘         └────┬────┘         └────┬────┘
     │                   │                   │                   │
     │ connect(token)    │                   │                   │
     │──────────────────>│                   │                   │
     │                   │                   │                   │
     │                   │ verify JWT        │                   │
     │                   │ assign user_id    │                   │
     │                   │                   │                   │
     │ join("match:123") │                   │                   │
     │──────────────────>│                   │                   │
     │                   │──────────────────>│                   │
     │                   │                   │                   │
     │                   │                   │ join(user_id)     │
     │                   │                   │──────────────────>│
     │                   │                   │                   │
     │                   │                   │              Assigns color
     │                   │                   │              Updates players
     │                   │                   │                   │
     │                   │                   │ {:ok, player_info}│
     │                   │                   │<──────────────────│
     │                   │                   │                   │
     │                   │                   │ broadcast         │
     │                   │                   │ "player_joined"   │
     │                   │                   │──────────────────>│
     │                   │                   │         (to all in channel)
     │                   │                   │                   │
     │ {:ok, state}      │                   │                   │
     │<──────────────────│                   │                   │
     │                   │                   │                   │
```

### 3. Gameplay Loop

```
┌─────────┐                              ┌─────────┐         ┌─────────┐
│ Frontend│                              │ Channel │         │GenServer│
└────┬────┘                              └────┬────┘         └────┬────┘
     │                                        │                   │
     │ (Host) push("start_game")              │                   │
     │───────────────────────────────────────>│                   │
     │                                        │                   │
     │                                        │ start_game()      │
     │                                        │──────────────────>│
     │                                        │                   │
     │                                        │              Sets status
     │                                        │              = :playing
     │                                        │              Starts timer
     │                                        │                   │
     │                   broadcast "game_started"                 │
     │<───────────────────────────────────────────────────────────│
     │                                        │                   │
     │                                        │                   │
     │  ┌─────── Every second ──────┐         │                   │
     │  │                           │         │              tick()
     │  │  broadcast "tick"         │         │              (self-sent)
     │  │  {time_remaining: 29}     │         │                   │
     │<─┼─────────────────────────────────────────────────────────│
     │  │                           │         │                   │
     │  └───────────────────────────┘         │                   │
     │                                        │                   │
     │ push("click_cell", {row: 1, col: 2})   │                   │
     │───────────────────────────────────────>│                   │
     │                                        │                   │
     │                                        │ click_cell(1,2)   │
     │                                        │──────────────────>│
     │                                        │                   │
     │                                        │              Updates grid
     │                                        │              Updates score
     │                                        │                   │
     │                   broadcast "cell_claimed"                 │
     │                   {row, col, user_id, color}               │
     │<───────────────────────────────────────────────────────────│
     │                                        │                   │
     │                                        │                   │
     │  ┌─────── When time = 0 ─────┐         │                   │
     │  │                           │         │              Calculates
     │  │  broadcast "game_ended"   │         │              winner
     │  │  {winner_id, scores}      │         │              Persists to DB
     │  │                           │         │                   │
     │<─┼─────────────────────────────────────────────────────────│
     │  │                           │         │                   │
     │  └───────────────────────────┘         │                   │
```

## Database Schema

### matches

```sql
CREATE TABLE matches (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(6) NOT NULL UNIQUE,      -- e.g., "ABC123"
    host_id BIGINT NOT NULL REFERENCES users(id),
    status VARCHAR(20) DEFAULT 'waiting', -- waiting | playing | finished
    grid_size INTEGER DEFAULT 4,          -- 4x4 grid
    duration_seconds INTEGER DEFAULT 30,  -- 30 second games
    winner_id BIGINT REFERENCES users(id),
    final_state JSONB,                    -- Stored at game end
    inserted_at TIMESTAMP,
    updated_at TIMESTAMP
);

CREATE INDEX matches_code_index ON matches(code);
CREATE INDEX matches_status_index ON matches(status);
```

### match_players

```sql
CREATE TABLE match_players (
    id BIGSERIAL PRIMARY KEY,
    match_id BIGINT NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users(id),
    color VARCHAR(7) NOT NULL,            -- e.g., "#FF5733"
    score INTEGER DEFAULT 0,
    joined_at TIMESTAMP,
    inserted_at TIMESTAMP,
    updated_at TIMESTAMP,
    UNIQUE(match_id, user_id)             -- One entry per player per match
);
```

## Backend Files

### Process Architecture

The match system uses OTP patterns for reliability:

```
Application Supervisor
         │
         ├── Registry (Backend.MatchRegistry)
         │   └── Maps {match_id} -> PID
         │
         └── DynamicSupervisor (Backend.Matches.MatchSupervisor)
             ├── MatchServer (match_id: 1)
             ├── MatchServer (match_id: 2)
             └── MatchServer (match_id: 3)
```

#### `lib/backend/application.ex`

Adds the Registry and DynamicSupervisor to the supervision tree:

```elixir
children = [
  # ... other children
  {Registry, keys: :unique, name: Backend.MatchRegistry},
  {Backend.Matches.MatchSupervisor, []}
]
```

### GenServer - Match State Machine

#### `lib/backend/matches/match_server.ex`

The MatchServer is the heart of the game logic. It maintains authoritative state and broadcasts updates.

**State Structure:**

```elixir
%{
  match_id: 123,
  match: %Match{},
  players: %{
    1 => %{user_id: 1, username: "alice", color: "#FF5733", score: 5},
    2 => %{user_id: 2, username: "bob", color: "#33FF57", score: 3}
  },
  grid: %{
    {0, 0} => 1,  # Cell claimed by user 1
    {0, 1} => 2,  # Cell claimed by user 2
    {1, 0} => 1
  },
  status: :playing,  # :waiting | :playing | :finished
  time_remaining: 25,
  timer_ref: #Reference<...>
}
```

**Key Functions:**

```elixir
# Start a new match process
def start_link(match) do
  GenServer.start_link(__MODULE__, match, name: via_tuple(match.id))
end

# Process registry lookup
defp via_tuple(match_id) do
  {:via, Registry, {Backend.MatchRegistry, match_id}}
end

# Player joins - assigns color from pool
def handle_call({:join, user_id, username, picture}, _from, state) do
  if map_size(state.players) >= 4 do
    {:reply, {:error, :match_full}, state}
  else
    color = get_next_color(state.players)
    player = %{user_id: user_id, username: username, picture: picture,
               color: color, score: 0}
    new_players = Map.put(state.players, user_id, player)

    broadcast(state.match_id, "player_joined", player)
    {:reply, {:ok, player}, %{state | players: new_players}}
  end
end

# Click cell - validates and updates grid
def handle_call({:click_cell, user_id, row, col}, _from, state) do
  cond do
    state.status != :playing ->
      {:reply, {:error, :not_playing}, state}
    not Map.has_key?(state.players, user_id) ->
      {:reply, {:error, :not_in_match}, state}
    true ->
      key = {row, col}
      previous_owner = Map.get(state.grid, key)

      # Update grid
      new_grid = Map.put(state.grid, key, user_id)

      # Update scores
      new_players = state.players
      |> maybe_decrement_score(previous_owner)
      |> increment_score(user_id)

      broadcast(state.match_id, "cell_claimed", %{
        row: row, col: col,
        user_id: user_id,
        color: state.players[user_id].color
      })

      {:reply, :ok, %{state | grid: new_grid, players: new_players}}
  end
end

# Timer tick - decrements and checks for game end
def handle_info(:tick, state) do
  new_time = state.time_remaining - 1

  if new_time <= 0 do
    end_game(state)
  else
    broadcast(state.match_id, "tick", %{time_remaining: new_time})
    timer_ref = Process.send_after(self(), :tick, 1000)
    {:noreply, %{state | time_remaining: new_time, timer_ref: timer_ref}}
  end
end
```

### Channels - Real-time Communication

#### `lib/backend_web/channels/user_socket.ex`

Authenticates WebSocket connections using JWT:

```elixir
defmodule BackendWeb.UserSocket do
  use Phoenix.Socket

  channel "match:*", BackendWeb.MatchChannel

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    case Backend.Guardian.decode_and_verify(token) do
      {:ok, claims} ->
        case Backend.Guardian.resource_from_claims(claims) do
          {:ok, user} ->
            {:ok, assign(socket, :user_id, user.id)
                  |> assign(:username, user.username)
                  |> assign(:picture, user.picture)}
          _ ->
            :error
        end
      _ ->
        :error
    end
  end

  def connect(_params, _socket, _connect_info), do: :error

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.user_id}"
end
```

#### `lib/backend_web/channels/match_channel.ex`

Handles match-specific events:

```elixir
defmodule BackendWeb.MatchChannel do
  use Phoenix.Channel
  alias Backend.Matches.MatchServer

  # Join the match channel
  def join("match:" <> match_id, _params, socket) do
    match_id = String.to_integer(match_id)
    user_id = socket.assigns.user_id

    case MatchServer.join(match_id, user_id,
                          socket.assigns.username,
                          socket.assigns.picture) do
      {:ok, player_info} ->
        # Subscribe to PubSub topic for this match
        Phoenix.PubSub.subscribe(Backend.PubSub, "match:#{match_id}")

        state = MatchServer.get_state(match_id)
        {:ok, state, assign(socket, :match_id, match_id)}
      {:error, reason} ->
        {:error, %{reason: to_string(reason)}}
    end
  end

  # Host starts the game
  def handle_in("start_game", _params, socket) do
    case MatchServer.start_game(socket.assigns.match_id, socket.assigns.user_id) do
      :ok -> {:reply, :ok, socket}
      {:error, reason} -> {:reply, {:error, %{reason: to_string(reason)}}, socket}
    end
  end

  # Player clicks a cell
  def handle_in("click_cell", %{"row" => row, "col" => col}, socket) do
    case MatchServer.click_cell(socket.assigns.match_id,
                                socket.assigns.user_id, row, col) do
      :ok -> {:reply, :ok, socket}
      {:error, reason} -> {:reply, {:error, %{reason: to_string(reason)}}, socket}
    end
  end

  # Forward PubSub broadcasts to the channel
  def handle_info({:broadcast, event, payload}, socket) do
    push(socket, event, payload)
    {:noreply, socket}
  end

  # Clean up when player leaves
  def terminate(_reason, socket) do
    if socket.assigns[:match_id] do
      MatchServer.leave(socket.assigns.match_id, socket.assigns.user_id)
    end
    :ok
  end
end
```

### REST API

#### `lib/backend_web/controllers/match_controller.ex`

```elixir
defmodule BackendWeb.MatchController do
  use BackendWeb, :controller
  alias Backend.Matches

  # GET /api/matches - List available matches
  def index(conn, _params) do
    matches = Matches.list_available_matches()
    render(conn, :index, matches: matches)
  end

  # POST /api/matches - Create a new match
  def create(conn, _params) do
    user = Guardian.Plug.current_resource(conn)

    case Matches.create_match(user) do
      {:ok, match} ->
        conn
        |> put_status(:created)
        |> render(:show, match: match)
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:error, changeset: changeset)
    end
  end

  # POST /api/matches/join - Join by code
  def join_by_code(conn, %{"code" => code}) do
    case Matches.get_match_by_code(code) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Match not found"})
      match ->
        render(conn, :show, match: match)
    end
  end
end
```

### Context - Database Operations

#### `lib/backend/matches.ex`

```elixir
defmodule Backend.Matches do
  alias Backend.Repo
  alias Backend.Matches.{Match, MatchPlayer, MatchServer, MatchSupervisor}

  # Generate unique 6-character code
  def generate_code do
    code = for _ <- 1..6, into: "", do: <<Enum.random(?A..?Z)>>
    if Repo.get_by(Match, code: code), do: generate_code(), else: code
  end

  # Create match and start GenServer
  def create_match(user) do
    attrs = %{
      code: generate_code(),
      host_id: user.id,
      status: "waiting"
    }

    case %Match{} |> Match.changeset(attrs) |> Repo.insert() do
      {:ok, match} ->
        match = Repo.preload(match, :host)
        MatchSupervisor.start_match(match)
        {:ok, match}
      error ->
        error
    end
  end

  # List matches that can be joined
  def list_available_matches do
    from(m in Match,
      where: m.status == "waiting",
      preload: [:host],
      order_by: [desc: m.inserted_at]
    )
    |> Repo.all()
    |> Enum.map(fn match ->
      player_count = MatchServer.player_count(match.id)
      Map.put(match, :player_count, player_count)
    end)
  end

  # Persist final game state
  def finish_match(match_id, winner_id, final_state) do
    match = Repo.get!(Match, match_id)

    match
    |> Match.changeset(%{
      status: "finished",
      winner_id: winner_id,
      final_state: final_state
    })
    |> Repo.update()
  end
end
```

## Frontend Files

### Type Definitions

#### `src/lib/api/types/match.ts`

```typescript
// Match as returned from REST API
export interface Match {
  id: number;
  code: string;
  host_id: number;
  host: {
    id: number;
    username: string | null;
    name: string | null;
    picture: string | null;
  };
  status: 'waiting' | 'playing' | 'finished';
  grid_size: number;
  duration_seconds: number;
  player_count: number;
}

// Player in a live match
export interface MatchPlayer {
  user_id: number;
  username: string | null;
  picture: string | null;
  color: string;
  score: number;
}

// Full match state (from WebSocket)
export interface MatchState {
  match_id: number;
  code: string;
  host_id: number;
  status: 'waiting' | 'playing' | 'finished';
  grid_size: number;
  duration_seconds: number;
  time_remaining: number;
  players: Record<number, MatchPlayer>;
  grid: Record<string, number>;  // "row,col" -> user_id
  winner_id: number | null;
}

// Channel events
export interface PlayerJoinedEvent {
  user_id: number;
  username: string | null;
  picture: string | null;
  color: string;
  score: number;
}

export interface CellClaimedEvent {
  row: number;
  col: number;
  user_id: number;
  color: string;
}

export interface TickEvent {
  time_remaining: number;
}

export interface GameEndedEvent {
  winner_id: number | null;
  scores: Record<number, number>;
}
```

### WebSocket Service

#### `src/lib/api/services/SocketService.ts`

```typescript
import { Socket, Channel } from 'phoenix';
import type { MatchState, MatchCallbacks } from '../types/match';

export class SocketService {
  private socket: Socket | null = null;
  private matchChannel: Channel | null = null;

  // Connect with JWT token
  connect(token: string): void {
    if (this.socket?.isConnected()) return;

    this.socket = new Socket('ws://localhost:4000/socket', {
      params: { token }
    });
    this.socket.connect();
  }

  // Join a match channel
  joinMatch(matchId: number, callbacks: MatchCallbacks): Promise<MatchState> {
    return new Promise((resolve, reject) => {
      if (!this.socket) {
        reject(new Error('Socket not connected'));
        return;
      }

      this.leaveMatch();
      this.matchChannel = this.socket.channel(`match:${matchId}`);

      // Set up event handlers
      this.matchChannel.on('player_joined', callbacks.onPlayerJoined);
      this.matchChannel.on('player_left', callbacks.onPlayerLeft);
      this.matchChannel.on('game_started', callbacks.onGameStarted);
      this.matchChannel.on('cell_claimed', callbacks.onCellClaimed);
      this.matchChannel.on('tick', callbacks.onTick);
      this.matchChannel.on('game_ended', callbacks.onGameEnded);

      this.matchChannel
        .join()
        .receive('ok', (state) => resolve(state as MatchState))
        .receive('error', (reason) => reject(new Error(reason.reason)));
    });
  }

  // Send events to server
  startGame(): Promise<void> {
    return this.push('start_game', {});
  }

  clickCell(row: number, col: number): Promise<void> {
    return this.push('click_cell', { row, col });
  }

  private push(event: string, payload: object): Promise<void> {
    return new Promise((resolve, reject) => {
      if (!this.matchChannel) {
        reject(new Error('Not in a match'));
        return;
      }

      this.matchChannel
        .push(event, payload)
        .receive('ok', () => resolve())
        .receive('error', (reason) => reject(new Error(reason.reason)));
    });
  }
}
```

### Reactive Store

#### `src/lib/stores/match.svelte.ts`

Uses Svelte 5 runes for reactive state:

```typescript
import { socketService } from '$lib/api/services/SocketService';
import type { MatchState, MatchPlayer } from '$lib/api/types/match';

class MatchStore {
  // Reactive state using $state rune
  private _players = $state<Record<number, MatchPlayer>>({});
  private _grid = $state<Record<string, number>>({});
  private _status = $state<'waiting' | 'playing' | 'finished'>('waiting');
  private _timeRemaining = $state(0);
  private _hostId = $state<number | null>(null);
  private _winnerId = $state<number | null>(null);
  private _gridSize = $state(4);
  private _code = $state('');
  private _isConnecting = $state(false);
  private _error = $state<string | null>(null);

  // Getters expose state
  get players() { return this._players; }
  get grid() { return this._grid; }
  get status() { return this._status; }
  get timeRemaining() { return this._timeRemaining; }
  get hostId() { return this._hostId; }
  get gridSize() { return this._gridSize; }
  get code() { return this._code; }
  get winnerId() { return this._winnerId; }
  get isConnecting() { return this._isConnecting; }
  get error() { return this._error; }

  // Derived state
  get playerList(): MatchPlayer[] {
    return Object.values(this._players);
  }

  get playerCount(): number {
    return Object.keys(this._players).length;
  }

  // Connect to WebSocket
  connect(token: string) {
    socketService.connect(token);
  }

  // Join match and wire up callbacks
  async joinMatch(matchId: number): Promise<void> {
    this._isConnecting = true;
    this._error = null;

    try {
      const state = await socketService.joinMatch(matchId, {
        onPlayerJoined: (event) => {
          this._players = { ...this._players, [event.user_id]: event };
        },
        onPlayerLeft: (event) => {
          const { [event.user_id]: _, ...rest } = this._players;
          this._players = rest;
        },
        onGameStarted: (event) => {
          this._status = 'playing';
          this._timeRemaining = event.time_remaining;
        },
        onCellClaimed: (event) => {
          const key = `${event.row},${event.col}`;
          this._grid = { ...this._grid, [key]: event.user_id };
          // Update scores
          if (this._players[event.user_id]) {
            this._players[event.user_id].score++;
          }
        },
        onTick: (event) => {
          this._timeRemaining = event.time_remaining;
        },
        onGameEnded: (event) => {
          this._status = 'finished';
          this._winnerId = event.winner_id;
          // Update final scores
          for (const [userId, score] of Object.entries(event.scores)) {
            if (this._players[Number(userId)]) {
              this._players[Number(userId)].score = score;
            }
          }
        }
      });

      // Initialize state from join response
      this._players = state.players;
      this._grid = state.grid;
      this._status = state.status;
      this._timeRemaining = state.time_remaining;
      this._hostId = state.host_id;
      this._gridSize = state.grid_size;
      this._code = state.code;
    } catch (e) {
      this._error = e instanceof Error ? e.message : 'Failed to join';
      throw e;
    } finally {
      this._isConnecting = false;
    }
  }

  // Game actions
  async startGame() {
    await socketService.startGame();
  }

  async clickCell(row: number, col: number) {
    await socketService.clickCell(row, col);
  }

  leaveMatch() {
    socketService.leaveMatch();
    this.reset();
  }

  private reset() {
    this._players = {};
    this._grid = {};
    this._status = 'waiting';
    this._timeRemaining = 0;
    this._hostId = null;
    this._winnerId = null;
    this._code = '';
    this._error = null;
  }
}

export const matchStore = new MatchStore();
```

### UI Components

#### `src/routes/lobby/+page.svelte`

```svelte
<script lang="ts">
  import { goto } from '$app/navigation';
  import { elyraClient } from '$lib/api';
  import type { Match } from '$lib/api/types/match';

  let matches = $state<Match[]>([]);
  let joinCode = $state('');
  let isCreating = $state(false);

  onMount(async () => {
    matches = await elyraClient.matches.listMatches();
  });

  async function createMatch() {
    isCreating = true;
    const match = await elyraClient.matches.createMatch();
    goto(`/match/${match.id}`);
  }

  async function joinByCode() {
    const match = await elyraClient.matches.joinByCode({
      code: joinCode.toUpperCase()
    });
    goto(`/match/${match.id}`);
  }
</script>

<div class="lobby">
  <!-- Create Match -->
  <button onclick={createMatch} disabled={isCreating}>
    Create Match
  </button>

  <!-- Join by Code -->
  <input bind:value={joinCode} placeholder="ABC123" maxlength="6" />
  <button onclick={joinByCode}>Join</button>

  <!-- Available Matches -->
  {#each matches as match}
    <div class="match-card">
      <span>{match.host.username}'s game</span>
      <span>{match.player_count}/4 players</span>
      <span>Code: {match.code}</span>
      <button onclick={() => goto(`/match/${match.id}`)}>Join</button>
    </div>
  {/each}
</div>
```

#### `src/routes/match/[id]/+page.svelte`

```svelte
<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { page } from '$app/stores';
  import { auth } from '$lib/stores/auth.svelte';
  import { matchStore } from '$lib/stores/match.svelte';

  const matchId = $derived(Number($page.params.id));
  const isHost = $derived(auth.user?.id === matchStore.hostId);

  onMount(async () => {
    matchStore.connect(auth.token);
    await matchStore.joinMatch(matchId);
  });

  onDestroy(() => {
    matchStore.leaveMatch();
  });

  function getCellColor(row: number, col: number): string | null {
    const key = `${row},${col}`;
    const ownerId = matchStore.grid[key];
    return ownerId ? matchStore.players[ownerId]?.color : null;
  }
</script>

{#if matchStore.status === 'waiting'}
  <!-- Waiting Room -->
  <h1>Code: {matchStore.code}</h1>
  <div class="players">
    {#each matchStore.playerList as player}
      <div style="border-color: {player.color}">
        {player.username}
      </div>
    {/each}
  </div>
  {#if isHost}
    <button
      onclick={() => matchStore.startGame()}
      disabled={matchStore.playerCount < 2}
    >
      Start Game
    </button>
  {/if}

{:else if matchStore.status === 'playing'}
  <!-- Game Grid -->
  <div class="timer">{matchStore.timeRemaining}s</div>
  <div class="grid" style="--size: {matchStore.gridSize}">
    {#each Array(matchStore.gridSize) as _, row}
      {#each Array(matchStore.gridSize) as _, col}
        {@const color = getCellColor(row, col)}
        <button
          onclick={() => matchStore.clickCell(row, col)}
          style:background-color={color || '#374151'}
        />
      {/each}
    {/each}
  </div>

{:else}
  <!-- Results -->
  <h1>Game Over!</h1>
  {#each matchStore.playerList.sort((a, b) => b.score - a.score) as player, i}
    <div>{i + 1}. {player.username}: {player.score}</div>
  {/each}
{/if}
```

## Key Concepts Explained

### Why GenServer?

GenServer provides:

1. **Server-authoritative state** - All game logic runs on the server, preventing cheating
2. **Concurrent handling** - Each match runs in its own process, isolated from others
3. **Fault tolerance** - If a match crashes, other matches continue running
4. **Process identity** - Registry allows finding a match process by ID

### Why Phoenix Channels?

Channels provide:

1. **Real-time bidirectional communication** - Events flow both ways instantly
2. **Presence tracking** - Built-in player join/leave detection (not used here, but available)
3. **Topic-based routing** - `match:123` naturally groups players
4. **Automatic reconnection** - Phoenix.js handles network issues

### Why PubSub for Broadcasting?

The GenServer broadcasts via PubSub rather than directly to channels because:

1. **Decoupling** - GenServer doesn't need to know about Channel implementation
2. **Multiple subscribers** - Any process can subscribe (logging, metrics, etc.)
3. **Pattern consistency** - Same pattern used throughout Phoenix

### State Flow

```
User clicks cell
       │
       ▼
Channel receives "click_cell"
       │
       ▼
Channel calls MatchServer.click_cell()
       │
       ▼
GenServer validates & updates state
       │
       ▼
GenServer broadcasts via PubSub
       │
       ▼
Channel handle_info receives broadcast
       │
       ▼
Channel pushes to all connected clients
       │
       ▼
Frontend SocketService triggers callback
       │
       ▼
matchStore updates reactive state
       │
       ▼
Svelte re-renders UI
```

## Testing the System

1. Start the backend: `cd backend && mix phx.server`
2. Start the frontend: `cd frontend && pnpm dev`
3. Open two browser windows
4. Log in as different users
5. User 1: Create a match
6. User 2: Join via code
7. User 1: Start the game
8. Both: Click cells to claim them!
9. Watch the timer count down
10. See final results

## Extending the System

Ideas for enhancement:

- **Power-ups**: Cells that give bonus points or special abilities
- **Cooldowns**: Prevent spam-clicking with rate limiting
- **Larger grids**: Support 6x6 or 8x8 grids
- **Spectators**: Allow non-players to watch
- **Rematch**: Quick restart with same players
- **Persistence**: Store match history for leaderboards
- **Animations**: Three.js visualization (mentioned in project goals)
