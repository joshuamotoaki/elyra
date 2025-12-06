# 𝚎𝚕𝚢𝚛𝚊

### COS426 Final Project, Princeton University, Fall 2025

A real-time multiplayer territory control game with 3D graphics. Players compete to capture the most territory by moving around the map and firing beams that claim tiles.

## Tech Stack

| Layer | Technology |
|-------|------------|
| Frontend | SvelteKit, TypeScript, Three.js, Threlte |
| Backend | Elixir, Phoenix, Phoenix Channels (WebSockets) |
| Database | PostgreSQL |
| Cache | Redis |
| Infrastructure | Docker, Docker Compose |

## Game Mechanics

### Objective
Capture the highest percentage of territory before time runs out (2 minutes).

### Controls
- **WASD** - Move your character
- **Mouse** - Aim direction
- **Click** - Fire a beam

### Territory Capture
- **Glow Radius**: Your character passively captures tiles within a glowing radius
- **Beams**: Fire energy beams that capture all tiles along their path
- **Generators**: Control generator tiles for bonus income

### Economy & Power-ups
Earn coins from:
- Passive income (1 coin/sec)
- Owning generators (3 coins/sec each)
- Collecting coin drops

Spend coins on power-ups:
| Power-up | Cost | Effect |
|----------|------|--------|
| Speed | 15 | +15% movement speed |
| Radius | 20 | +0.25 glow radius |
| Energy | 20 | +25 max energy, faster regen |
| Multishot | 40 | Fire 3 beams in spread pattern |
| Piercing | 35 | Beams pass through 1 wall |
| Beam Speed | 30 | Double beam velocity |

### Map Features
- **Walls** - Block movement and beams
- **Mirrors** - Reflect beams at 90 degrees
- **Generators** - Provide bonus income when owned
- **Holes** - Destroy beams on contact

### Game Modes
- **Multiplayer** (2-4 players): Compete for territory in 2-minute matches
- **Solo Practice**: No time limit, practice mechanics freely

## Architecture

```
elyra/
├── backend/                    # Elixir/Phoenix API & game server
│   ├── lib/backend/
│   │   ├── accounts/          # User management & OAuth
│   │   └── matches/           # Game logic
│   │       ├── match_server.ex    # GenServer: 20Hz game loop
│   │       ├── player_state.ex    # Player state & power-ups
│   │       ├── beam_physics.ex    # Beam movement & collision
│   │       ├── economy.ex         # Coins & income
│   │       └── map_generator.ex   # Procedural map generation
│   └── lib/backend_web/
│       ├── channels/          # WebSocket real-time communication
│       └── controllers/       # REST API endpoints
│
├── frontend/                   # SvelteKit + Three.js client
│   └── src/
│       ├── routes/            # Pages (lobby, match, etc.)
│       └── lib/
│           ├── api/           # API client & WebSocket service
│           ├── stores/        # Svelte state management
│           └── components/
│               └── game/      # 3D rendering (Three.js/Threlte)
│
└── docker-compose.yml         # Container orchestration
```

### Real-time Communication

The game runs at **20Hz server tick rate** using Phoenix Channels (WebSockets):

1. **Client sends**: Input state (WASD), shoot commands, power-up purchases
2. **Server processes**: Physics, collisions, territory capture, economy
3. **Server broadcasts**: State deltas (only changed data) to all players
4. **Client interpolates**: Smooth rendering between server updates

## API Reference

### REST Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/auth/google` | Initiate Google OAuth |
| GET | `/api/users/me` | Get current user |
| PUT | `/api/users/username` | Set username |
| GET | `/api/matches` | List public matches |
| POST | `/api/matches` | Create match |
| POST | `/api/matches/join` | Join by code |

### WebSocket Events

**Channel**: `match:{id}`

| Direction | Event | Description |
|-----------|-------|-------------|
| Client → Server | `input` | Movement keys (WASD) |
| Client → Server | `shoot` | Fire beam with direction |
| Client → Server | `buy_powerup` | Purchase power-up |
| Client → Server | `start_game` | Host starts match |
| Server → Client | `state_delta` | Game state update (20Hz) |
| Server → Client | `player_joined` | New player entered |
| Server → Client | `player_left` | Player disconnected |
| Server → Client | `game_started` | Match begun |
| Server → Client | `game_ended` | Match finished with scores |

## Development Setup

### Prerequisites

- Docker and Docker Compose
- Make
- For local backend: Elixir/Erlang
- For local frontend: Node.js and pnpm

### Quick Start

**Run everything in Docker:**
```bash
make dev-full
# Frontend at localhost:3000, Backend at localhost:4000
```

**Backend + frontend locally (databases in Docker):**
```bash
make dev-local
cd backend && mix phx.server   # Terminal 1
cd frontend && pnpm dev        # Terminal 2
```

**Frontend only (backend + databases in Docker):**
```bash
make dev-frontend
cd frontend && pnpm dev
```

### Commands

| Command | Description |
|---------|-------------|
| `make dev-full` | Run everything in Docker |
| `make dev-local` | Run databases in Docker |
| `make dev-frontend` | Run backend + databases in Docker |
| `make down` | Stop all containers |
| `make db-clear` | Delete all database data |
| `make logs` | Tail logs from all services |
| `make migrate` | Run database migrations |

### Ports

| Service | Port |
|---------|------|
| Frontend | 3000 |
| Backend | 4000 |
| PostgreSQL | 5432 |
| Redis | 6380 |

### Environment

Local database URL:
```
postgresql://postgres:postgres@localhost:5432/elyra
```

Local Redis URL:
```
redis://localhost:6380
```

## Database Schema

### Users
- `google_id` - OAuth identifier
- `email` - User email
- `username` - Display name (3-30 chars)
- `picture` - Profile picture URL

### Matches
- `code` - 6-character join code
- `status` - waiting | playing | finished
- `is_public` - Visible in lobby
- `is_solo` - Solo practice mode
- `host_id` - User who created match
- `winner_id` - Winner (if finished)

### Match Players
- `match_id` - Associated match
- `user_id` - Player
- `color` - Assigned color (#EF4444, #3B82F6, #22C55E, #F59E0B)
- `score` - Final territory percentage
