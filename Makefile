# VibeMon - Makefile
# Quick commands for development and deployment

.PHONY: help dev build start stop logs test lint clean

# Default target
help:
	@echo "VibeMon Development Commands"
	@echo "=============================="
	@echo "make dev       - Start development environment"
	@echo "make build     - Build all Docker images"
	@echo "make start     - Start production environment"
	@echo "make stop      - Stop all services"
	@echo "make logs      - View logs"
	@echo "make test      - Run all tests"
	@echo "make lint      - Run linters"
	@echo "make clean     - Clean up containers and volumes"
	@echo ""
	@echo "Component-specific:"
	@echo "make firmware  - Build ESP32 firmware"
	@echo "make mobile    - Build mobile app"
	@echo "make api       - Run API tests"

# Development
dev:
	docker-compose up -d

build:
	docker-compose build

start:
	docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d

stop:
	docker-compose down

logs:
	docker-compose logs -f

# Testing
test: api-test mobile-test

api-test:
	cd backend/api && poetry run pytest

mobile-test:
	cd mobile && flutter test

# Linting
lint:
	cd backend/api && poetry run ruff check . && poetry run black --check .
	cd admin && npm run lint
	cd mobile && flutter analyze

# Firmware
firmware:
	cd firmware && pio run

firmware-upload:
	cd firmware && pio run -t upload

# Mobile
mobile:
	cd mobile && flutter build apk --release

mobile-ios:
	cd mobile && flutter build ios --release

# Clean
clean:
	docker-compose down -v --remove-orphans
	cd mobile && flutter clean
	cd firmware && pio run -t clean

# Database
db-migrate:
	cd backend/api && poetry run alembic upgrade head

db-rollback:
	cd backend/api && poetry run alembic downgrade -1

# Documentation
docs:
	@echo "Documentation available at docs/"
