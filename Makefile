.PHONY: dev-local dev-frontend dev-full \
        db-up db-down db-clear down logs-backend logs-frontend \
        backend-shell frontend-shell migrate

# =============================================================================
# WORKFLOW 1: DBs in Docker, backend and/or frontend local
# Usage: make dev-local, then run backend and/or frontend manually
# =============================================================================
dev-local: db-up
	@echo ""
	@echo "✓ Databases running"
	@echo "  → Postgres: localhost:5432"
	@echo "  → Redis:    localhost:6380"
	@echo ""
	@echo "Now run locally:"
	@echo "  cd backend && mix phx.server"
	@echo "  cd frontend && pnpm dev"
	@echo ""

# =============================================================================
# WORKFLOW 2: DBs + Backend in Docker, frontend local
# Usage: make dev-frontend, then cd frontend && pnpm dev
# =============================================================================
dev-frontend:
	docker compose --profile backend up -d --build
	@echo ""
	@echo "✓ Backend stack running"
	@echo "  → Postgres: localhost:5432"
	@echo "  → Redis:    localhost:6380"
	@echo "  → Backend:  localhost:4000"
	@echo ""
	@echo "Now run your frontend locally:"
	@echo "  cd frontend && pnpm dev"
	@echo ""

# =============================================================================
# WORKFLOW 3: Everything in Docker (prod-like)
# Usage: make dev-full
# =============================================================================
dev-full:
	docker compose --profile full up -d --build
	@echo ""
	@echo "✓ Full stack running in Docker"
	@echo "  → Postgres: localhost:5432"
	@echo "  → Redis:    localhost:6380"
	@echo "  → Backend:  localhost:4000"
	@echo "  → Frontend: localhost:3000"
	@echo ""

# =============================================================================
# Database commands
# =============================================================================
db-up:
	docker compose up -d postgres redis

db-down:
	docker compose stop postgres redis

db-clear:
	docker compose down -v postgres redis

# =============================================================================
# General commands
# =============================================================================
down:
	docker compose --profile full down

down-all:
	docker compose --profile full down -v

logs-backend:
	docker compose logs -f backend

logs-frontend:
	docker compose logs -f frontend

logs:
	docker compose --profile full logs -f

backend-shell:
	docker compose exec backend sh

frontend-shell:
	docker compose exec frontend sh

migrate:
	docker compose exec backend mix ecto.migrate

# =============================================================================
# Help
# =============================================================================
help:
	@echo "Elyra Development Commands"
	@echo ""
	@echo "Workflows:"
	@echo "  make dev-local     - DBs in Docker, run backend and/or frontend locally"
	@echo "  make dev-frontend  - DBs + backend in Docker, run frontend locally"
	@echo "  make dev-full      - Everything in Docker (prod-like)"
	@echo ""
	@echo "Database:"
	@echo "  make db-up         - Start databases"
	@echo "  make db-down       - Stop databases"
	@echo "  make db-clear      - Stop databases and delete data"
	@echo ""
	@echo "Other:"
	@echo "  make down          - Stop all containers"
	@echo "  make logs          - Tail all logs"
	@echo "  make migrate       - Run database migrations"