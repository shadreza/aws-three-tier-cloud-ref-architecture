# Short commands for everyday work. Type `make` to see them all.
# Everything runs inside Docker, so you do not need Go or Node installed.

COMPOSE    := docker compose
GO_IMAGE   := golang:1.25-alpine
NODE_IMAGE := node:22-alpine
BACKEND    := $(CURDIR)/app/backend
WEB        := $(CURDIR)/app/web
ME         := $(shell id -u):$(shell id -g)

.DEFAULT_GOAL := help
.PHONY: help up down restart ps logs seed check rollup migrate db test test-backend test-web fmt reset

help: ## Show this list
	@echo "Usage: make <command>"
	@echo ""
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "} {printf "  %-14s %s\n", $$1, $$2}'

up: ## Build and start the whole app
	$(COMPOSE) up -d --build
	@echo ""
	@echo "  App: http://localhost:5173"
	@echo "  API: http://localhost:8080/api/health"
	@echo ""
	@echo "  First start takes a minute while the web container installs packages."
	@echo "  Watch it with: make logs s=web"

down: ## Stop the app (your data is kept)
	$(COMPOSE) down

restart: ## Rebuild and restart (use after changing Go code)
	$(COMPOSE) up -d --build

ps: ## Show which services are running
	$(COMPOSE) ps

logs: ## Follow the logs. Just one service: make logs s=api
	$(COMPOSE) logs -f $(s)

seed: ## Add a few example monitors
	$(COMPOSE) run --rm api seed

check: ## Run the check job once, right now
	$(COMPOSE) run --rm api check

rollup: ## Run the rollup job once, right now
	$(COMPOSE) run --rm api rollup

migrate: ## Create or update the database tables
	$(COMPOSE) run --rm migrate

db: ## Open a MySQL prompt inside the database
	$(COMPOSE) exec mysql mysql -uuptime -puptime uptime

test: test-backend test-web ## Run all tests

test-backend: ## Run the Go tests
	docker run --rm -v $(BACKEND):/src -v uptime-go-mod:/go/pkg/mod -v uptime-go-build:/root/.cache/go-build \
		-w /src $(GO_IMAGE) sh -c "go vet ./... && go test ./..."

test-web: ## Type-check and build the frontend
	$(COMPOSE) run --rm --no-deps web sh -c "npm ci --no-audit --no-fund && npm run typecheck && npx vite build --outDir /tmp/dist"

fmt: ## Format the Go code
	docker run --rm --user $(ME) -v $(BACKEND):/src -w /src $(GO_IMAGE) gofmt -l -w .

reset: ## Stop the app and DELETE all local data (database, reports)
	$(COMPOSE) down -v
