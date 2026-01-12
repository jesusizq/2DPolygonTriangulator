# Makefile for 3D Processor

# Default shell
SHELL := /bin/bash

# Project configuration
PROJECT_NAME := 3d-processor
COMPOSE_COMMAND := docker compose -f docker/docker-compose.yml

# Variable for service target, can be overridden
service ?= all

# Environment selection (dev, prod, test)
env ?= development

# Determine environment files to use
ENV_FILES :=
ifeq ($(env),production)
    SPECIFIC_ENV := .env.production
else ifeq ($(env),test)
    SPECIFIC_ENV := .env.test
else
    SPECIFIC_ENV := .env.development
endif

# Load .env if it exists
ifneq ($(wildcard .env),)
    ENV_FILES += --env-file .env
    include .env
    export
endif

# Load specific env file if it exists (overriding .env)
ifneq ($(wildcard $(SPECIFIC_ENV)),)
    ENV_FILES += --env-file $(SPECIFIC_ENV)
    include $(SPECIFIC_ENV)
    export
endif

ENV_FILE_ARG := $(ENV_FILES)

# Always include override for production environment
ifeq ($(env),production)
    COMPOSE_COMMAND := $(COMPOSE_COMMAND) -f docker/docker-compose.override.yml
endif

.PHONY: help build up down clean logs exec test build-test test-rebuild health status dev-up init-submodules install-deps build-wasm

help:
	@echo "3D Processor - Development Commands"
	@echo "===================================="
	@echo ""
	@echo "Quick Start:"
	@echo "  make build && make up : Build and start all services"
	@echo ""
	@echo "Available Commands:"
	@echo "  build [env=<env>]  : Build all Docker images (default: development)"
	@echo "  up [env=<env>]     : Start all services (default: development)"
	@echo "  down [env=<env>]   : Stop all services"
	@echo "  dev-up             : Start services in development mode with hot reload"
	@echo "  clean              : Stop and remove all containers, volumes, and images"
	@echo "  logs service=<name>: Follow logs for a specific service (default: all)"
	@echo "  exec service=<name> cmd=\"...\": Execute command in running container"
	@echo "  test               : Run tests (builds test image if not exists)"
	@echo "  build-test         : Build test Docker image"
	@echo "  test-rebuild       : Force rebuild test image and run tests"
	@echo "  health             : Check health status of all services"
	@echo "  status             : Show status of all services"
	@echo "  init-submodules    : Initialize git submodules if not present"
	@echo "  install-deps       : Install npm dependencies for frontend"
	@echo "  build-wasm         : Build WASM module for frontend"
	@echo ""
	@echo "Services: mesh-processor, frontend"
	@echo "Environments: development (default), production, test"
	@echo ""
	@echo "Examples:"
	@echo "  make up env=production    # Start in production mode"
	@echo "  make logs service=mesh-processor"
	@echo "  make exec service=mesh-processor cmd=\"ls -la\""

init-submodules:
	@echo "Updating git submodules recursively..."
	git submodule update --init --recursive

# Install npm dependencies if not present
install-deps:
	@echo "Checking npm dependencies..."
	@if [ ! -d "frontend/node_modules" ]; then \
		echo "Installing npm dependencies..."; \
		cd frontend && npm install; \
	else \
		echo "✓ npm dependencies already installed"; \
	fi

build-wasm: init-submodules install-deps
	@echo "Building WASM module..."
	cd frontend && npm run build:wasm

build: init-submodules build-wasm
	@echo "Building images for environment: $(env)..."
	$(COMPOSE_COMMAND) $(ENV_FILE_ARG) build --parallel
	@echo "✓ Build completed"

up:
	@echo "Starting services for environment: $(env)..."
	$(COMPOSE_COMMAND) $(ENV_FILE_ARG) up -d --remove-orphans
	@echo "✓ Services started"
	@echo "Gateway (HTTP)  : http://localhost:$(GATEWAY_HTTP_PORT)"
	@echo "Gateway (HTTPS) : https://localhost:$(GATEWAY_HTTPS_PORT)"
	@echo "API Proxy       : http://localhost:$(GATEWAY_HTTP_PORT)/api/health"

dev-up:
	@echo "Starting services in development mode..."
	$(COMPOSE_COMMAND) $(ENV_FILE_ARG) up -d --remove-orphans
	@echo "✓ Development services started"
	@echo "Gateway (HTTP)  : http://localhost:$(GATEWAY_HTTP_PORT)"

down:
	@echo "Stopping services for environment: $(env)..."
	$(COMPOSE_COMMAND) $(ENV_FILE_ARG) down
	@echo "✓ Services stopped"

clean:
	@echo "Cleaning up all Docker resources..."
	@echo "Stopping and removing containers..."
	$(COMPOSE_COMMAND) $(ENV_FILE_ARG) down -v --remove-orphans || true
	@echo "Removing project images..."
	docker images | grep $(PROJECT_NAME) | awk '{print $$3}' | xargs -r docker rmi -f || true
	@echo "Pruning unused Docker resources..."
	docker system prune -f
	@echo "✓ Cleanup completed"

logs:
ifeq ($(service),all)
	$(COMPOSE_COMMAND) $(ENV_FILE_ARG) logs -f
else
	$(COMPOSE_COMMAND) $(ENV_FILE_ARG) logs -f $(service)
endif

exec:
	@if [ -z "$(cmd)" ]; then \
		echo "Command missing. Use: make exec service=<service> cmd=\"your command\""; \
		exit 1; \
	fi
	@if [ "$(service)" = "all" ]; then \
		echo "Please specify a specific service name"; \
		exit 1; \
	fi
	$(COMPOSE_COMMAND) $(ENV_FILE_ARG) exec $(service) $(cmd)

test:
	@echo "Running tests..."
	@if ! docker image inspect $(PROJECT_NAME)-test >/dev/null 2>&1; then \
		echo "Test image not found, building..."; \
		$(MAKE) build-test; \
	fi
	@echo "Executing tests in container..."
	docker run --rm $(PROJECT_NAME)-test
	@echo "✓ Tests completed"

build-test:
	@echo "Building test environment..."
	docker build --target test --progress=plain -t $(PROJECT_NAME)-test ./mesh-processor
	@echo "✓ Test image built"

test-rebuild:
	@echo "Rebuilding and running tests..."
	docker build --target test --progress=plain --no-cache -t $(PROJECT_NAME)-test ./mesh-processor
	docker run --rm $(PROJECT_NAME)-test
	@echo "✓ Tests completed"

health:
	@echo "Checking service health..."
	@echo "Mesh Processor (via Gateway):"
	@curl -sf http://localhost:$(GATEWAY_HTTP_PORT)/api/health || echo "  Unhealthy"
	@echo ""
	@echo "Frontend (via Gateway):"
	@curl -sf http://localhost:$(GATEWAY_HTTP_PORT)/health && echo "  ✓ Healthy" || echo " Unhealthy"

status:
	@echo "Service Status:"
	$(COMPOSE_COMMAND) $(ENV_FILE_ARG) ps

# Convenience targets for specific services
mesh-processor-up:
	$(COMPOSE_COMMAND) $(ENV_FILE_ARG) up -d mesh-processor

frontend-up:
	$(COMPOSE_COMMAND) $(ENV_FILE_ARG) up -d frontend

mesh-processor-logs:
	$(COMPOSE_COMMAND) $(ENV_FILE_ARG) logs -f mesh-processor

frontend-logs:
	$(COMPOSE_COMMAND) $(ENV_FILE_ARG) logs -f frontend

# Build individual services
build-mesh-processor:
	$(COMPOSE_COMMAND) $(ENV_FILE_ARG) build mesh-processor

build-frontend:
	$(COMPOSE_COMMAND) $(ENV_FILE_ARG) build frontend

# Development helpers
wasm-build: init-submodules
	@echo "Building WASM module manually..."
	cd frontend && ./build-wasm.sh
	@echo "✓ WASM module built"

mesh-processor-shell:
	$(COMPOSE_COMMAND) $(ENV_FILE_ARG) exec mesh-processor /bin/bash 