# 𝚎𝚕𝚢𝚛𝚊

### COS426 Final Project, Princeton University, Fall 2025

## Development Setup

This project uses Docker for local development. Choose the workflow that fits your needs:

### Prerequisites

- Docker and Docker Compose
- Make
- For local backend development: Elixir/Erlang
- For local frontend development: Node.js (install with nvm) and pnpm

### Workflows

**Working on the backend?** Run databases in Docker, backend locally:

```bash
make dev-backend
cd backend && mix phx.server
```

**Working on the frontend?** Run databases and backend in Docker, frontend locally:

```bash
make dev-frontend
cd frontend
nvm use
pnpm install
pnpm dev
```

**Working on both?** Run just databases in Docker:

```bash
make dev-local
# Terminal 1
cd backend && mix phx.server

# Terminal 2
cd frontend
nvm use
pnpm install
pnpm dev
```

**Testing the full stack?** Run everything in Docker (mirrors production):

```bash
make dev-full
# Frontend at localhost:3000, Backend at localhost:4000
```

### Other Commands

| Command             | Description                                         |
| ------------------- | --------------------------------------------------- |
| `make down`         | Stop all containers                                 |
| `make db-clear`     | Stop databases and delete all data                  |
| `make logs`         | Tail logs from all services                         |
| `make logs-backend` | Tail backend logs                                   |
| `make migrate`      | Run database migrations (when backend is in Docker) |
| `make help`         | Show all available commands                         |

### Ports

| Service  | Port |
| -------- | ---- |
| Frontend | 3000 |
| Backend  | 4000 |
| Postgres | 5432 |
| Redis    | 6380 |
