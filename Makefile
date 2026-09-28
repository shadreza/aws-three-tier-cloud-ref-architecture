# Short commands for everyday work. Type `make` to see them all.
# Everything runs inside Docker, so you do not need Go or Node installed.

COMPOSE    := docker compose
GO_IMAGE   := golang:1.25-alpine
NODE_IMAGE := node:22-alpine
BACKEND    := $(CURDIR)/app/backend
WEB        := $(CURDIR)/app/web
ME         := $(shell id -u):$(shell id -g)

.DEFAULT_GOAL := help
.PHONY: help up down restart ps logs seed check rollup migrate db test test-backend test-web fmt reset \
	tf-bootstrap tf-plan tf-apply tf-destroy tf-output tf-fmt tf-validate image-push image-use

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

# ---- Terraform (from step 02 on) ----------------------------------------------
#
# Terraform also runs in Docker. Your AWS login (~/.aws) is passed in, so these
# commands act on whatever account AWS_PROFILE points at. Only the tf-plan,
# tf-apply, tf-destroy, tf-output and tf-bootstrap commands talk to AWS.
#
#   make tf-plan  env=dev stack=network
#   make tf-apply env=dev stack=network
#
# Each environment keeps its own .terraform folder (TF_DATA_DIR), so a plan for
# dev can never run against prod's state by accident.

TF_IMAGE  := hashicorp/terraform:1.16
TF_STACKS := network security data registry compute edge jobs observability cicd
TTY       := $(shell test -t 0 && echo -t)
TF_RUN     = docker run --rm -i $(TTY) --user $(ME) \
	-v $(CURDIR):/repo -v $(HOME)/.aws:/home/tf/.aws \
	-e HOME=/home/tf -e AWS_PROFILE -e AWS_REGION -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY -e AWS_SESSION_TOKEN \
	-e TF_PLUGIN_CACHE_DIR=/repo/terraform/.plugin-cache -e TF_IN_AUTOMATION=1 \
	-w /repo/terraform $(TF_IMAGE)
TF_ENV_RUN = docker run --rm -i $(TTY) --user $(ME) \
	-v $(CURDIR):/repo -v $(HOME)/.aws:/home/tf/.aws \
	-e HOME=/home/tf -e AWS_PROFILE -e AWS_REGION -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY -e AWS_SESSION_TOKEN \
	-e TF_PLUGIN_CACHE_DIR=/repo/terraform/.plugin-cache -e TF_IN_AUTOMATION=1 \
	-e TF_DATA_DIR=.terraform/$(env) \
	-w /repo/terraform/stacks/$(stack) $(TF_IMAGE)
TF_VARS    = -var-file=../../envs/$(env)/common.tfvars $(if $(wildcard terraform/envs/$(env)/$(stack).tfvars),-var-file=../../envs/$(env)/$(stack).tfvars) $(vars)

tf-guard:
	@test -n "$(env)" || (echo "set env, for example: make $(MAKECMDGOALS) env=dev stack=network" && exit 1)
	@test -n "$(stack)" || (echo "set stack, one of: $(TF_STACKS)" && exit 1)
	@test -d terraform/stacks/$(stack) || (echo "no stack terraform/stacks/$(stack)" && exit 1)
	@test -f terraform/envs/$(env)/common.tfvars || (echo "no environment terraform/envs/$(env)" && exit 1)
	@mkdir -p terraform/.plugin-cache terraform/.plans $(HOME)/.aws

tf-init: tf-guard
	@$(TF_ENV_RUN) init -input=false -reconfigure \
		-backend-config=../../envs/$(env)/backend.hcl -backend-config=key=$(env)/$(stack).tfstate 1>&2

tf-bootstrap: ## Create the state bucket and a budget, once per account: make tf-bootstrap account_id=... budget_email=...
	@test -n "$(account_id)" || (echo "set account_id, for example: make tf-bootstrap account_id=123456789012" && exit 1)
	@mkdir -p terraform/.plugin-cache
	$(TF_RUN) -chdir=bootstrap init -input=false
	$(TF_RUN) -chdir=bootstrap apply -var account_id=$(account_id) -var budget_email=$(budget_email)

tf-plan: tf-init ## Show what Terraform would change: make tf-plan env=dev stack=network
	$(TF_ENV_RUN) plan -input=false $(TF_VARS) -out=/repo/terraform/.plans/$(env)-$(stack).tfplan

tf-apply: tf-guard ## Apply the plan made by tf-plan: make tf-apply env=dev stack=network
	@test -f terraform/.plans/$(env)-$(stack).tfplan || (echo "run make tf-plan env=$(env) stack=$(stack) first" && exit 1)
	$(TF_ENV_RUN) apply -input=false /repo/terraform/.plans/$(env)-$(stack).tfplan
	@rm -f terraform/.plans/$(env)-$(stack).tfplan

tf-destroy: tf-init ## Delete everything in one stack: make tf-destroy env=dev stack=network
	$(TF_ENV_RUN) destroy $(TF_VARS)

tf-output: tf-init ## Show a stack's outputs: make tf-output env=dev stack=network [name=vpc_id]
	@$(TF_ENV_RUN) output $(if $(name),-raw $(name))

tf-fmt: ## Format the Terraform code
	$(TF_RUN) fmt -recursive

tf-validate: ## Check the Terraform code without touching AWS
	@mkdir -p terraform/.plugin-cache
	$(TF_RUN) fmt -check -recursive
	@for dir in bootstrap $(addprefix stacks/,$(TF_STACKS)); do \
		test -d terraform/$$dir || continue; \
		echo "== $$dir"; \
		$(TF_RUN) -chdir=$$dir init -input=false -backend=false >/dev/null && \
		$(TF_RUN) -chdir=$$dir validate -no-color || exit 1; \
	done

# ---- Container image (from step 04 on) --------------------------------------------
#
# Build the backend for ARM (Fargate Graviton), push it to the environment's
# ECR repository, and choose which tag the environment runs. Both talk to AWS.
#
#   make image-push env=dev            builds and pushes tag = current git commit
#   make image-use  env=dev tag=abc123 the next compute apply runs this tag

AWS_ACCOUNT = $(shell awk -F'"' '/^account_id/ {print $$2}' terraform/envs/$(env)/common.tfvars 2>/dev/null)
AWS_REGION_ = $(shell awk -F'"' '/^region/ {print $$2}' terraform/envs/$(env)/common.tfvars 2>/dev/null)
REGISTRY    = $(AWS_ACCOUNT).dkr.ecr.$(AWS_REGION_).amazonaws.com
IMAGE_REPO  = $(REGISTRY)/uptime-$(env)/backend
GIT_TAG     = $(shell git rev-parse --short=12 HEAD)

image-push: ## Build the ARM image and push it to ECR: make image-push env=dev
	@test -n "$(env)" || (echo "set env, for example: make image-push env=dev" && exit 1)
	@git diff --quiet HEAD -- app/backend || (echo "app/backend has uncommitted changes; commit first so the tag means something" && exit 1)
	aws ecr get-login-password --region $(AWS_REGION_) | docker login --username AWS --password-stdin $(REGISTRY)
	docker buildx build --platform linux/arm64 --provenance=false -t $(IMAGE_REPO):$(GIT_TAG) --push app/backend
	@echo ""
	@echo "  Pushed $(IMAGE_REPO):$(GIT_TAG)"
	@echo "  Run it with: make image-use env=$(env) tag=$(GIT_TAG), then plan and apply the compute stack"

image-use: ## Set the image tag the environment runs: make image-use env=dev tag=abc123
	@test -n "$(env)" -a -n "$(tag)" || (echo "set env and tag, for example: make image-use env=dev tag=abc123" && exit 1)
	aws ssm put-parameter --region $(AWS_REGION_) --name /uptime-$(env)/image-tag --type String --value $(tag) --overwrite
