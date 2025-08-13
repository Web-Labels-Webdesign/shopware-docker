# Shopware Docker - Product Requirements Document

## Project Overview

**Project Name**: Shopware Docker  
**GitHub Organization**: Web-Labels-Webdesign  
**Repository**: `Web-Labels-Webdesign/shopware-docker`  
**Version**: 1.0  
**Date**: August 2025  
**Status**: Draft

### Executive Summary
Create a custom Docker image based on dockware/dev that eliminates permission issues in development environments and provides additional developer tools. The image will support seamless file access across Linux and Windows hosts while maintaining Shopware development best practices.

## Problem Statement

Current dockware/dev usage requires manual permission management on Linux:
- Files created in container (www-data UID 33) become inaccessible on host (user UID 1000+)
- Files created on host require ownership changes for container access
- Constant `chown` commands disrupt development flow
- Multiple plugin repositories need the same permission fixes

**Windows Note**: Windows developers using Docker Desktop don't experience these permission issues due to automatic mapping, but need the same base image for consistency.

## Goals and Objectives

### Primary Goals
1. **Zero-friction permissions on Linux**: Automatic UID/GID mapping for seamless file access
2. **Windows compatibility**: Ensure existing Windows workflows continue unchanged
3. **Clean integration**: Drop-in replacement for dockware/dev images
4. **Multi-version support**: Support for multiple dockware/dev base versions (Phase 2+)

### Success Metrics
- Elimination of manual `chown` commands on Linux hosts
- Zero configuration changes required in existing docker-compose files
- No functional changes for Windows developers
- Bi-weekly automated builds maintain version currency

## Technical Requirements

### Permission Management (Phase 1)
- **Linux Hosts**: Automatic UID/GID mapping for www-data to match host user
- **Windows Hosts**: No changes required (Docker Desktop handles mapping)
- **Dynamic Configuration**: Container detects host UID/GID at startup
- **Volume Ownership**: Automatic ownership correction for mounted volumes

### Base Image Support (Phase 1: Single Version)
- Start with latest dockware/dev version (6.6.10.4)
- Maintain full compatibility with existing functionality
- **Phase 2+**: Expand to multiple versions with matrix builds

### Additional Tools (Phase 2+)
- Enhanced development tools (TBD based on team needs)
- Shell environment improvements
- Performance optimizations

### Container Features
- **Smart Entrypoint**: Detects host environment and configures permissions
- **Environment Detection**: Automatic Linux/Windows/macOS host detection
- **Volume Optimization**: Proper ownership for mounted volumes
- **Service Management**: Maintains all dockware services while adding features

## Architecture Design

### Image Structure
```
shopware-docker
├── base: dockware/dev:${VERSION}
├── entrypoint: smart-entrypoint.sh
├── configs: optimized configurations
└── scripts: utility scripts
```

### Permission Strategy
```bash
# Linux: Map container users to host UID/GID
# Windows: Use Docker Desktop's native volume mapping
# Detection: Automatic host OS detection in entrypoint
```

### Build Matrix

**Phase 1** (Single Version):
| Base Version | Status           |
| ------------ | ---------------- |
| 6.6.10.4     | ✅ Primary target |

**Phase 2+** (Multi-Version):
| Base Version | PHP Versions | Node Versions |
| ------------ | ------------ | ------------- |
| 6.6.10.4     | 8.1, 8.2     | 18, 20        |
| 6.5.8.10     | 8.1, 8.2     | 18, 20        |
| 6.4.20.2     | 8.0, 8.1     | 16, 18        |

## GitHub Actions Pipeline

### Workflow Triggers
- **Schedule**: Bi-weekly check for new dockware releases
- **Manual**: Workflow dispatch for immediate builds
- **Push**: Changes to main branch trigger rebuilds
- **PR**: Build validation for pull requests

### Build Strategy

**Phase 1** (Single Version):
```yaml
strategy:
  matrix:
    dockware_version: [6.6.10.4]
```

**Phase 2+** (Multi-Version):
```yaml
strategy:
  matrix:
    dockware_version: [6.6.10.4, 6.5.8.10, 6.4.20.2]
    include:
      - dockware_version: 6.6.10.4
        php_versions: "8.1,8.2"
        node_version: "20"
      - dockware_version: 6.5.8.10
        php_versions: "8.1,8.2"  
        node_version: "18"
```

### Image Tagging
- `latest`: Most recent stable build
- `v{major}.{minor}`: Version-specific tags
- `dockware-{version}`: Base dockware version mapping
- `experimental`: Development builds

### Registry Strategy
- **Primary**: GitHub Container Registry (ghcr.io/web-labels-webdesign/shopware-docker)
- **Secondary**: Docker Hub for public access (if needed)
- **Retention**: Keep last 10 versions, cleanup older builds

## User Experience

### Installation
```bash
# Replace existing dockware usage
services:
  shopware:
    image: ghcr.io/web-labels-webdesign/shopware-docker:dockware-6.6.10.4
    # ... rest of configuration unchanged
```

### Automatic Features
- Permission mapping happens transparently
- No configuration changes required
- Maintains all existing dockware functionality
- Additional tools available immediately

### Environment Variables
```bash
SHOPWARE_DOCKER_AUTO_PERMISSIONS=true    # Enable automatic permission handling
SHOPWARE_DOCKER_HOST_UID=auto           # Auto-detect or manual override
SHOPWARE_DOCKER_HOST_GID=auto           # Auto-detect or manual override
SHOPWARE_DOCKER_DEBUG=false             # Enable debug output
```

## Implementation Phases

### Phase 1: Minimal Viable Product (Weeks 1-2)
**Goal**: Solve the core permission problem with minimal complexity

- [x] Smart entrypoint script for Linux UID/GID mapping
- [x] Single dockware version support (6.6.10.4)
- [x] Basic GitHub Actions workflow
- [x] Windows compatibility validation (ensure no breakage)
- [x] Drop-in replacement functionality

**Success Criteria**: 
- Linux developers can edit files without `chown` commands
- Windows developers experience no functional changes
- Zero configuration changes required in docker-compose files

### Phase 2: Multi-Version Support (Weeks 3-4)
**Goal**: Expand to support team's dockware version requirements

- [ ] Matrix builds for multiple dockware versions
- [ ] Automated version detection and building
- [ ] Enhanced CI/CD with proper testing
- [ ] Documentation for version selection

### Phase 3: Enhanced Developer Experience (Weeks 5-8)
**Goal**: Add value-added tools and optimizations

- [ ] Additional development tools (based on team feedback)
- [ ] Shell environment improvements
- [ ] Performance optimizations
- [ ] Advanced CI/CD features

## Technical Specifications

### Dockerfile Structure (Phase 1)
```dockerfile
ARG DOCKWARE_VERSION=6.6.10.4
FROM dockware/dev:${DOCKWARE_VERSION}

# Copy minimal permission-fixing entrypoint
COPY smart-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/smart-entrypoint.sh

# Set up entrypoint (maintains original CMD)
ENTRYPOINT ["/usr/local/bin/smart-entrypoint.sh"]
CMD ["supervisord"]
```

**Phase 2+ Enhancement**:
```dockerfile
# Additional tools installation
RUN apt-get update && apt-get install -y \
    zsh \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*
```

### Smart Entrypoint Logic
1. Detect host operating system
2. Determine host user UID/GID from volume ownership
3. Configure container users accordingly
4. Set up volume permissions
5. Execute original dockware entrypoint

## Risk Assessment

### Technical Risks
- **Risk**: Permission mapping complexity across different host environments
- **Mitigation**: Extensive testing on Linux, Windows, macOS

- **Risk**: Breaking changes in dockware base images
- **Mitigation**: Automated testing, version pinning, gradual rollouts

### Operational Risks
- **Risk**: CI/CD pipeline complexity
- **Mitigation**: Staged rollout, comprehensive testing, rollback procedures

- **Risk**: Maintenance overhead for multiple versions
- **Mitigation**: Automated workflows, clear deprecation policy

## Success Criteria

### Functional Requirements
- ✅ Eliminate manual permission commands
- ✅ Maintain full dockware compatibility
- ✅ Support major host operating systems
- ✅ Automated multi-version builds

### Performance Requirements
- Container startup time: < 30 seconds additional overhead
- Image size increase: < 500MB compared to base dockware
- Build time: < 15 minutes per version in CI

### Quality Requirements
- 100% automated testing coverage for permission scenarios
- Documentation coverage for all features
- Zero breaking changes to existing docker-compose configurations

## Open Questions

### Phase 1 Questions
1. **Volume Mount Strategy**: Should we handle single plugin mounts differently than full Shopware mounts?
2. **Error Handling**: How should the entrypoint behave if UID/GID detection fails?
3. **Testing Strategy**: What's the minimum test coverage for Linux permission scenarios?

### Phase 2+ Questions  
4. **Tool Selection**: Which additional tools provide the most value for Shopware development?
5. **Version Strategy**: Should we follow semantic versioning or mirror dockware versions?
6. **Windows CI Testing**: How do we validate Windows compatibility in GitHub Actions?
7. **Team Rollout**: What's the migration strategy from existing dockware usage?

## Appendix

### Related Documentation
- [Dockware Documentation](https://docs.dockware.io/)
- [Docker Multi-platform Builds](https://docs.docker.com/build/building/multi-platform/)
- [GitHub Actions Docker Builds](https://docs.github.com/en/actions/publishing-packages/publishing-docker-images)

### Change Log
- v1.0 - Initial PRD draft