# Contributing to Shopware Docker

We welcome contributions to make Shopware Docker better! This document provides guidelines for contributing to the project.

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Process](#development-process)
- [Testing](#testing)
- [Submitting Changes](#submitting-changes)
- [Release Process](#release-process)

## Code of Conduct

This project follows a standard code of conduct. Be respectful, inclusive, and constructive in all interactions.

## Getting Started

### Prerequisites

- Docker and Docker Compose
- Git
- Basic knowledge of Docker, Bash scripting, and Shopware

### Development Setup

1. **Fork and clone the repository:**
   ```bash
   git clone https://github.com/your-username/shopware-docker.git
   cd shopware-docker
   ```

2. **Build development image:**
   ```bash
   docker build -t shopware-docker-dev .
   ```

3. **Run smoke tests:**
   ```bash
   ./.github/scripts/smoke-test.sh shopware-docker-dev
   ```

## Development Process

### Branch Strategy

- `main`: Stable release branch
- `develop`: Development branch for new features
- `feature/*`: Feature branches
- `fix/*`: Bug fix branches
- `release/*`: Release preparation branches

### Making Changes

1. **Create a feature branch:**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes following these guidelines:**
   - Keep changes focused and atomic
   - Follow existing code style
   - Add comments for complex logic
   - Update documentation as needed

3. **Test your changes:**
   ```bash
   # Build and test locally
   docker build -t shopware-docker-test .
   ./.github/scripts/smoke-test.sh shopware-docker-test
   
   # Test permission handling
   ./test-permissions.sh  # If you create integration tests
   ```

### Code Style Guidelines

#### Dockerfile
- Use multi-stage builds when beneficial
- Minimize layer count
- Use specific version tags
- Add meaningful labels
- Follow security best practices

#### Shell Scripts
- Use `#!/bin/bash` shebang
- Enable strict mode with `set -e`
- Use meaningful variable names
- Add error handling
- Include debugging output when appropriate
- Follow shellcheck recommendations

#### Documentation
- Keep README.md up to date
- Use clear, concise language
- Include practical examples
- Update CHANGELOG.md for user-facing changes

## Testing

### Local Testing

1. **Syntax Testing:**
   ```bash
   # Test Dockerfile syntax
   docker build --dry-run .
   
   # Test shell script syntax
   bash -n smart-entrypoint.sh
   shellcheck smart-entrypoint.sh
   ```

2. **Smoke Testing:**
   ```bash
   # Build and run basic smoke test
   docker build -t test-image .
   ./.github/scripts/smoke-test.sh test-image
   ```

3. **Permission Testing:**
   ```bash
   # Create test scenario
   mkdir -p ./test-volume
   echo "test" > ./test-volume/test-file.txt
   
   # Run container with volume mount
   docker run -d --name perm-test \
     -v "$(pwd)/test-volume:/var/www/html/test" \
     -e SHOPWARE_DOCKER_DEBUG=true \
     test-image
   
   # Test file operations
   docker exec perm-test touch /var/www/html/test/container-file.txt
   ls -la ./test-volume/  # Should show proper ownership
   
   # Cleanup
   docker stop perm-test && docker rm perm-test
   rm -rf ./test-volume
   ```

### Automated Testing

The CI/CD pipeline runs:
- Dockerfile linting (hadolint)
- Shell script linting (shellcheck)
- Multi-platform builds
- Smoke tests
- Security scanning (Trivy)
- Integration tests

## Submitting Changes

### Pull Request Process

1. **Ensure your branch is up to date:**
   ```bash
   git checkout main
   git pull upstream main
   git checkout your-feature-branch
   git rebase main
   ```

2. **Create a pull request with:**
   - Clear, descriptive title
   - Detailed description of changes
   - Reference to related issues
   - Screenshots/logs if applicable

3. **PR Requirements:**
   - All tests pass
   - Code follows style guidelines
   - Documentation is updated
   - Changes are backward compatible (or breaking changes are documented)

### PR Template

```markdown
## Description
Brief description of changes made.

## Type of Change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update

## Testing
- [ ] Local testing completed
- [ ] Smoke tests pass
- [ ] Permission tests pass (if applicable)
- [ ] Multi-platform compatibility verified

## Checklist
- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] CHANGELOG.md updated (if user-facing change)
```

## Release Process

### Version Strategy

We follow [Semantic Versioning](https://semver.org/):
- `MAJOR.MINOR.PATCH` (e.g., 2.1.0)
- Major: Breaking changes
- Minor: New features (backward compatible)
- Patch: Bug fixes (backward compatible)

### Release Steps

1. **Prepare release branch:**
   ```bash
   git checkout -b release/v2.1.0
   ```

2. **Update version files:**
   - Update CHANGELOG.md
   - Update version in documentation
   - Update image tags in examples

3. **Create release PR:**
   - Target: `main` branch
   - Include all changes since last release
   - Update documentation

4. **After merge:**
   - Tag release: `git tag -a v2.1.0 -m "Release v2.1.0"`
   - Push tag: `git push origin v2.1.0`
   - CI/CD builds and publishes images automatically

## Common Tasks

### Adding Support for New Dockware Version

1. **Update version detection:**
   ```bash
   # In .github/workflows/build-and-push.yml
   # Add new version to the versions array
   ```

2. **Test new version:**
   ```bash
   docker build --build-arg DOCKWARE_VERSION=6.x.x.x -t test-new-version .
   ./.github/scripts/smoke-test.sh test-new-version
   ```

3. **Update documentation:**
   - Add to README.md version table
   - Update examples

### Improving Permission Handling

1. **Test on different systems:**
   - Linux with various UID/GID combinations
   - Docker Desktop on Windows/macOS
   - Different volume mount scenarios

2. **Add debug logging:**
   ```bash
   debug_log "Your debug message here"
   ```

3. **Handle edge cases:**
   - Missing mount points
   - Permission conflicts
   - Network mounts

### Adding New Features

1. **Follow the principle of least surprise**
   - New features should not break existing workflows
   - Default behavior should be sensible
   - Provide opt-out mechanisms

2. **Add configuration options:**
   - Use environment variables
   - Document in README.md and .env.example
   - Provide sensible defaults

3. **Test thoroughly:**
   - Multiple dockware versions
   - Different host systems
   - Various usage scenarios

## Getting Help

- 📖 Check existing [documentation](README.md)
- 🐛 Search [existing issues](https://github.com/Web-Labels-Webdesign/shopware-docker/issues)
- 💬 Start a [discussion](https://github.com/Web-Labels-Webdesign/shopware-docker/discussions)
- 📧 Contact maintainers

Thank you for contributing to Shopware Docker! 🎉