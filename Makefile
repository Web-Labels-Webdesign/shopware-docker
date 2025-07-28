# Shopware Development Docker - Modern Build System
# Inspired by shopwareLabs/devcontainer best practices

# Configuration
REGISTRY ?= ghcr.io
NAMESPACE ?= weblabels/shopware-docker
IMAGE_NAME ?= shopware-dev
PLATFORMS ?= linux/amd64,linux/arm64

# Version configuration
SHOPWARE_65_VERSION := 6.5.8.18
SHOPWARE_66_VERSION := 6.6.10.6  
SHOPWARE_67_VERSION := 6.7.1.0
DEFAULT_VERSION := $(SHOPWARE_67_VERSION)

# Build configuration
BUILDX_BUILDER := shopware-builder
CACHE_TYPE ?= gha
PUSH ?= false

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
PURPLE := \033[0;35m
CYAN := \033[0;36m
NC := \033[0m # No Color

# Helper function to print colored output
define print
	@echo "$(2)$(1)$(NC)"
endef

.PHONY: help
help: ## Show this help message
	@echo "$(BLUE)Shopware Development Docker - Build System$(NC)"
	@echo "=========================================="
	@echo ""
	@echo "$(YELLOW)Available commands:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(CYAN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Examples:$(NC)"
	@echo "  make build                    # Build all images"
	@echo "  make build-67                 # Build Shopware 6.7 only"
	@echo "  make build-slim               # Build all slim variants"
	@echo "  make push                     # Build and push all images"
	@echo "  make setup                    # Setup development environment"
	@echo "  make clean                    # Clean build artifacts"

.PHONY: init
init: ## Initialize development environment
	$(call print,🚀 Initializing Shopware Docker development environment,$(BLUE))
	@mkdir -p build-config
	@mkdir -p cache
	@docker buildx create --name $(BUILDX_BUILDER) --use --driver docker-container --driver-opt network=host 2>/dev/null || true
	$(call print,✅ Environment initialized,$(GREEN))

.PHONY: matrix
matrix: init ## Generate dynamic build matrix
	$(call print,📊 Generating dynamic build matrix,$(BLUE))
	@node scripts/generate-matrix.mjs
	$(call print,✅ Build matrix generated,$(GREEN))

.PHONY: prepare
prepare: matrix ## Prepare build contexts for all versions
	$(call print,📦 Preparing build contexts,$(BLUE))
	@rm -rf build/
	@mkdir -p build
	
	# Prepare 6.5 context
	@mkdir -p build/$(SHOPWARE_65_VERSION)
	@cp -r 6.5/* build/$(SHOPWARE_65_VERSION)/
	@sed -i 's/ENV SHOPWARE_VERSION=.*/ENV SHOPWARE_VERSION=$(SHOPWARE_65_VERSION)/' build/$(SHOPWARE_65_VERSION)/Dockerfile
	@sed -i 's/ENV PHP_VERSION=.*/ENV PHP_VERSION=8.2/' build/$(SHOPWARE_65_VERSION)/Dockerfile
	
	# Prepare 6.6 context  
	@mkdir -p build/$(SHOPWARE_66_VERSION)
	@cp -r 6.6/* build/$(SHOPWARE_66_VERSION)/
	@sed -i 's/ENV SHOPWARE_VERSION=.*/ENV SHOPWARE_VERSION=$(SHOPWARE_66_VERSION)/' build/$(SHOPWARE_66_VERSION)/Dockerfile
	@sed -i 's/ENV PHP_VERSION=.*/ENV PHP_VERSION=8.3/' build/$(SHOPWARE_66_VERSION)/Dockerfile
	
	# Prepare 6.7 context
	@mkdir -p build/$(SHOPWARE_67_VERSION)
	@cp -r 6.7/* build/$(SHOPWARE_67_VERSION)/
	@sed -i 's/ENV SHOPWARE_VERSION=.*/ENV SHOPWARE_VERSION=$(SHOPWARE_67_VERSION)/' build/$(SHOPWARE_67_VERSION)/Dockerfile
	@sed -i 's/ENV PHP_VERSION=.*/ENV PHP_VERSION=8.4/' build/$(SHOPWARE_67_VERSION)/Dockerfile
	
	$(call print,✅ Build contexts prepared,$(GREEN))

# Build targets using Docker Bake
.PHONY: build
build: prepare ## Build all Docker images using Bake
	$(call print,🏗️ Building all Shopware images with Docker Bake,$(BLUE))
	@docker buildx bake --file docker-bake.hcl all
	$(call print,🎉 All images built successfully,$(GREEN))

.PHONY: build-full
build-full: prepare ## Build all full variant images
	$(call print,🏗️ Building full variant images,$(BLUE))
	@docker buildx bake --file docker-bake.hcl all-full
	$(call print,✅ Full variant images built,$(GREEN))

.PHONY: build-slim  
build-slim: prepare ## Build all slim variant images
	$(call print,🏗️ Building slim variant images,$(BLUE))
	@docker buildx bake --file docker-bake.hcl all-slim
	$(call print,✅ Slim variant images built,$(GREEN))

.PHONY: build-65
build-65: prepare ## Build Shopware 6.5 images
	$(call print,🏗️ Building Shopware 6.5 images,$(BLUE))
	@docker buildx bake --file docker-bake.hcl shopware-6-5-full shopware-6-5-slim
	$(call print,✅ Shopware 6.5 images built,$(GREEN))

.PHONY: build-66
build-66: prepare ## Build Shopware 6.6 images  
	$(call print,🏗️ Building Shopware 6.6 images,$(BLUE))
	@docker buildx bake --file docker-bake.hcl shopware-6-6-full shopware-6-6-slim
	$(call print,✅ Shopware 6.6 images built,$(GREEN))

.PHONY: build-67
build-67: prepare ## Build Shopware 6.7 images (latest)
	$(call print,🏗️ Building Shopware 6.7 images,$(BLUE))
	@docker buildx bake --file docker-bake.hcl shopware-6-7-full shopware-6-7-slim
	$(call print,✅ Shopware 6.7 images built,$(GREEN))

.PHONY: build-latest
build-latest: build-67 ## Build latest version (6.7)

# Push targets
.PHONY: push
push: prepare ## Build and push all images to registry
	$(call print,🚀 Building and pushing all images to $(REGISTRY),$(BLUE))
	@docker buildx bake --file docker-bake.hcl --push all
	$(call print,🎉 All images pushed successfully,$(GREEN))

.PHONY: push-latest
push-latest: prepare ## Build and push latest images
	$(call print,🚀 Building and pushing latest images,$(BLUE))
	@docker buildx bake --file docker-bake.hcl --push latest
	$(call print,✅ Latest images pushed,$(GREEN))

# Development targets
.PHONY: test
test: ## Run image tests
	$(call print,🧪 Running image tests,$(BLUE))
	@echo "Testing latest full image..."
	@docker run --rm -d --name test-shopware -p 8080:80 $(REGISTRY)/$(NAMESPACE)/$(IMAGE_NAME):latest
	@timeout 180 bash -c 'until curl -f http://localhost:8080/api/_info/version 2>/dev/null; do sleep 5; echo "Waiting for Shopware..."; done'
	@curl -f http://localhost:8080/api/_info/version || (docker logs test-shopware && exit 1)
	@docker stop test-shopware
	$(call print,✅ Tests passed,$(GREEN))

.PHONY: setup
setup: init ## Quick project setup
	$(call print,🎯 Setting up new Shopware project,$(BLUE))
	@read -p "Project name (default: shopware-project): " PROJECT_NAME; \
	PROJECT_NAME=$${PROJECT_NAME:-shopware-project}; \
	read -p "Shopware version (default: $(DEFAULT_VERSION)): " SW_VERSION; \
	SW_VERSION=$${SW_VERSION:-$(DEFAULT_VERSION)}; \
	echo "Creating project: $$PROJECT_NAME with Shopware $$SW_VERSION"; \
	./setup.sh "$$PROJECT_NAME" "$$SW_VERSION"
	$(call print,🎉 Project setup complete,$(GREEN))

.PHONY: dev
dev: ## Start development environment (requires setup first)
	$(call print,🚀 Starting development environment,$(BLUE))
	@if [ -f docker-compose.yml ]; then \
		docker-compose up -d; \
		echo "$(GREEN)✅ Development environment started$(NC)"; \
		echo "$(CYAN)🌐 Frontend: http://localhost$(NC)"; \
		echo "$(CYAN)🏪 Admin: http://localhost/admin$(NC)"; \
		echo "$(CYAN)📧 MailHog: http://localhost:8025$(NC)"; \
	else \
		echo "$(RED)❌ No docker-compose.yml found. Run 'make setup' first.$(NC)"; \
		exit 1; \
	fi

.PHONY: stop
stop: ## Stop development environment
	$(call print,🛑 Stopping development environment,$(BLUE))
	@docker-compose down 2>/dev/null || echo "No development environment running"
	$(call print,✅ Environment stopped,$(GREEN))

.PHONY: logs
logs: ## Show development environment logs
	@docker-compose logs -f shopware 2>/dev/null || echo "$(YELLOW)No development environment running$(NC)"

.PHONY: shell
shell: ## Access container shell
	@docker-compose exec shopware bash 2>/dev/null || echo "$(RED)Development environment not running. Start with 'make dev'$(NC)"

# Maintenance targets
.PHONY: clean
clean: ## Clean build artifacts and caches
	$(call print,🧹 Cleaning build artifacts,$(YELLOW))
	@rm -rf build/
	@rm -rf build-config/
	@docker system prune -f --filter "label=maintainer=Development Team" 2>/dev/null || true
	@docker buildx prune -f 2>/dev/null || true
	$(call print,✅ Cleanup complete,$(GREEN))

.PHONY: clean-all
clean-all: clean ## Clean everything including volumes
	$(call print,🧹 Deep cleaning everything,$(YELLOW))
	@docker system prune -a -f --volumes 2>/dev/null || true
	@docker buildx rm $(BUILDX_BUILDER) 2>/dev/null || true
	$(call print,✅ Deep cleanup complete,$(GREEN))

.PHONY: inspect
inspect: ## Show build configuration and status
	$(call print,🔍 Build Configuration Status,$(BLUE))
	@echo "$(YELLOW)Registry:$(NC) $(REGISTRY)"
	@echo "$(YELLOW)Namespace:$(NC) $(NAMESPACE)"  
	@echo "$(YELLOW)Image Name:$(NC) $(IMAGE_NAME)"
	@echo "$(YELLOW)Platforms:$(NC) $(PLATFORMS)"
	@echo "$(YELLOW)Builder:$(NC) $(BUILDX_BUILDER)"
	@echo ""
	@echo "$(YELLOW)Supported Versions:$(NC)"
	@echo "  • Shopware 6.5: $(SHOPWARE_65_VERSION)"
	@echo "  • Shopware 6.6: $(SHOPWARE_66_VERSION)" 
	@echo "  • Shopware 6.7: $(SHOPWARE_67_VERSION) (latest)"
	@echo ""
	@echo "$(YELLOW)Docker Buildx Status:$(NC)"
	@docker buildx ls 2>/dev/null || echo "  Buildx not available"

.PHONY: version
version: matrix ## Show version information
	$(call print,📋 Version Information,$(BLUE))
	@if [ -f build-config/build-summary.json ]; then \
		echo "$(YELLOW)Build Summary:$(NC)"; \
		cat build-config/build-summary.json | jq -r '"Total Variants: " + (.total_variants | tostring)'; \
		cat build-config/build-summary.json | jq -r '"Shopware Versions: " + (.shopware_versions | join(", "))'; \
		cat build-config/build-summary.json | jq -r '"PHP Versions: " + (.php_versions | join(", "))'; \
		cat build-config/build-summary.json | jq -r '"Variants: " + (.variants | join(", "))'; \
	else \
		echo "$(RED)Build configuration not found. Run 'make matrix' first.$(NC)"; \
	fi

# Default target
.DEFAULT_GOAL := help