# 𝚎𝚕𝚢𝚛𝚊

### COS426 Final Project, Princeton University, Fall 2025

Play the game at [elyra.tigerapps.org](https://elyra.tigerapps.org) 🎉

⚡ A fast-paced multiplayer arena game where players battle for territory using energy beams that bounce off mirrors, pierce through walls, and paint the map in their color. Capture generators for bonus income, spend coins on powerful upgrades, and outmaneuver opponents in 2-minute matches. Solo practice or up to 4-player competitive chaos — all rendered in 3D with a rotatable camera. 🎮

Project Writeup: https://docs.google.com/document/d/1PifD66PaWbdBMH4Bfm7FqKWGwO2FxnwhrYRq6K-Fxjk/edit?usp=sharing

Demo Video: https://www.youtube.com/watch?v=iNiSVniPqPk

## Tech Stack

| Layer | Technology |
|-------|------------|
| Frontend | SvelteKit, TypeScript, Three.js, Threlte |
| Backend | Elixir, Phoenix, Phoenix Channels (WebSockets) |
| Database | PostgreSQL |
| Infrastructure & CI/CD | Docker, AWS EC2, GitHub Actions |

## Game Mechanics

### Objective
Capture the highest percentage of territory before time runs out (2 minutes).

### Game Modes
- **Multiplayer (2-4 players)** - Compete for territory in 2-minute matches
- **Solo Practice** - No time limit, practice mechanics freely

### Controls
- **WASD or arrow keys** - Move your character
- **Mouse** - Aim direction
- **Click and drag** - Rotate game board
- **Space Bar** - Fire a beam

### Territory Capture
- **Glow Radius** - Your character passively captures tiles within a glowing radius
- **Beams** - Fire energy beams that capture all tiles along their path
- **Generators** - Control generator tiles for bonus income

### Map Features
- **Tiles** - Walkable and colored same color as player who captured it
- **Walls** - Block movement and beams
- **Holes** - Block movement
- **Mirrors** - Reflect beams at 90 degrees
- **Generators** - Provide bonus income when owned

### Economy & Power-ups
Earn coins from:
- Passive income (1 coin/sec)
- Owning generators (3 coins/sec each)

Spend coins on power-ups:
| Power-up | Stackability | Cost | Effect |
|----------|-----------|------|--------|
| Speed | Stackable | 15 + 20 * stack | +15% movement speed |
| Radius | Stackable | 20 + 20 * stack | +0.25 glow radius |
| Energy | Stackable | 20 + 20 * stack | +25 max energy, faster regen |
| Multishot | One-time purchase | 75 | Fire 3 beams in spread pattern |
| Pierce | One-time purchase | 50 | Beams pass through 1 wall |
| Fast Beam | One-time purchase | 40 | Double beam velocity |

## Architecture

```
elyra/
├── backend/                       # Elixir/Phoenix API & game server
│   └── lib/
│       ├── backend/
│       │   ├── accounts/          # User management
│       │   ├── guardian.ex        # JWT authentication
│       │   └── matches/           # Game logic
│       │       ├── match_server.ex     # GenServer: 20Hz game loop
│       │       ├── match_supervisor.ex # DynamicSupervisor for matches
│       │       ├── beam_physics.ex     # DDA ray-casting & reflections
│       │       ├── player_state.ex     # Player state & power-ups
│       │       ├── economy.ex          # Coins & income
│       │       └── map_generator.ex    # Procedural map generation
│       └── backend_web/
│           ├── channels/          # WebSocket (Phoenix Channels)
│           ├── controllers/       # REST API endpoints
│           └── plugs/             # Auth pipeline & middleware
│
├── frontend/                      # SvelteKit + Three.js client
│   └── src/
│       ├── routes/                # Pages (/, lobby, match/[id], onboarding)
│       └── lib/
│           ├── api/
│           │   ├── services/      # Auth, Match, Socket, User services
│           │   └── types/         # TypeScript interfaces
│           ├── stores/            # Svelte state (auth, game)
│           ├── game/              # Input handling & game logic
│           └── components/
│               ├── game/          # 3D scene (GameCanvas, TileGrid, PlayerAvatar, BeamEffect)
│               ├── ui/            # Reusable UI (Button, Card, Modal, etc.)
│               └── layout/        # Header, PageBackground
│
├── docker-compose.yml             # Dev container orchestration
└── docker-compose.prod.yml        # Production deployment
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

### Environment

Local database URL:
```
postgresql://postgres:postgres@localhost:5432/elyra
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
- `color` - Assigned color (#3B82F6, #EF4444, #22C55E, #F59E0B)
- `score` - Final territory percentage
