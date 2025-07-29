# Shopware Docker Development Makefile

.PHONY: help build build-all up down logs clean test

# Default target
help: ## Show this help message
	@echo "Shopware Docker Development Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Build commands
build-6.5: ## Build Shopware 6.5 image
	docker build --build-arg SHOPWARE_VERSION=6.5 --build-arg PHP_VERSION=8.1 -t shopware-dev:6.5 .

build-6.6: ## Build Shopware 6.6 image
	docker build --build-arg SHOPWARE_VERSION=6.6 --build-arg PHP_VERSION=8.2 -t shopware-dev:6.6 .

build-6.7: ## Build Shopware 6.7 image
	docker build --build-arg SHOPWARE_VERSION=6.7 --build-arg PHP_VERSION=8.3 -t shopware-dev:6.7 .

build-all: build-6.5 build-6.6 build-6.7 ## Build all Shopware versions

# Docker Compose commands
up: ## Start all containers
	docker-compose up -d

up-6.5: ## Start only Shopware 6.5
	docker-compose up -d shopware-6.5

up-6.6: ## Start only Shopware 6.6
	docker-compose up -d shopware-6.6

up-6.7: ## Start only Shopware 6.7
	docker-compose up -d shopware-6.7

down: ## Stop all containers
	docker-compose down

logs: ## Show logs for all containers
	docker-compose logs -f

logs-6.5: ## Show logs for Shopware 6.5
	docker-compose logs -f shopware-6.5

logs-6.6: ## Show logs for Shopware 6.6
	docker-compose logs -f shopware-6.6

logs-6.7: ## Show logs for Shopware 6.7
	docker-compose logs -f shopware-6.7

# Development commands
shell-6.5: ## Open shell in Shopware 6.5 container
	docker exec -it shopware-dev-6.5 /bin/bash

shell-6.6: ## Open shell in Shopware 6.6 container
	docker exec -it shopware-dev-6.6 /bin/bash

shell-6.7: ## Open shell in Shopware 6.7 container
	docker exec -it shopware-dev-6.7 /bin/bash

mysql-6.5: ## Connect to MySQL in Shopware 6.5
	docker exec -it shopware-dev-6.5 mysql -u shopware -p shopware

mysql-6.6: ## Connect to MySQL in Shopware 6.6
	docker exec -it shopware-dev-6.6 mysql -u shopware -p shopware

mysql-6.7: ## Connect to MySQL in Shopware 6.7
	docker exec -it shopware-dev-6.7 mysql -u shopware -p shopware

# Plugin management
plugin-install-6.5: ## Install plugin in Shopware 6.5
	docker exec shopware-dev-6.5 php bin/console plugin:refresh
	docker exec shopware-dev-6.5 php bin/console plugin:install --activate WebLaSplitComission

plugin-install-6.6: ## Install plugin in Shopware 6.6
	docker exec shopware-dev-6.6 php bin/console plugin:refresh
	docker exec shopware-dev-6.6 php bin/console plugin:install --activate WebLaSplitComission

plugin-install-6.7: ## Install plugin in Shopware 6.7
	docker exec shopware-dev-6.7 php bin/console plugin:refresh
	docker exec shopware-dev-6.7 php bin/console plugin:install --activate WebLaSplitComission

# Testing
test: ## Test all images
	@echo "Testing Shopware 6.5..."
	docker run --rm -d --name test-6.5 -p 8065:80 shopware-dev:6.5
	@sleep 60
	@curl -f http://localhost:8065/admin && echo "✅ Shopware 6.5 OK" || echo "❌ Shopware 6.5 Failed"
	@docker stop test-6.5
	
	@echo "Testing Shopware 6.6..."
	docker run --rm -d --name test-6.6 -p 8066:80 shopware-dev:6.6
	@sleep 60
	@curl -f http://localhost:8066/admin && echo "✅ Shopware 6.6 OK" || echo "❌ Shopware 6.6 Failed"
	@docker stop test-6.6
	
	@echo "Testing Shopware 6.7..."
	docker run --rm -d --name test-6.7 -p 8067:80 shopware-dev:6.7
	@sleep 60
	@curl -f http://localhost:8067/admin && echo "✅ Shopware 6.7 OK" || echo "❌ Shopware 6.7 Failed"
	@docker stop test-6.7

# Cleanup
clean: ## Remove all containers and images
	docker-compose down -v
	docker rmi shopware-dev:6.5 shopware-dev:6.6 shopware-dev:6.7 2>/dev/null || true

clean-volumes: ## Remove all volumes
	docker-compose down -v
	docker volume prune -f

# Status
status: ## Show status of all containers
	docker-compose ps

# URLs
urls: ## Show access URLs
	@echo "🌐 Access URLs:"
	@echo "Shopware 6.5: http://localhost:8065 (Admin: http://localhost:8065/admin)"
	@echo "Shopware 6.6: http://localhost:8066 (Admin: http://localhost:8066/admin)"
	@echo "Shopware 6.7: http://localhost:8067 (Admin: http://localhost:8067/admin)"
	@echo ""
	@echo "📊 Database connections:"
	@echo "Shopware 6.5: localhost:3365 (user: shopware, password: shopware)"
	@echo "Shopware 6.6: localhost:3366 (user: shopware, password: shopware)"
	@echo "Shopware 6.7: localhost:3367 (user: shopware, password: shopware)"
