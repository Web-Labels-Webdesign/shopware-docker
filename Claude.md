<!--
chatgpt-agent-instructions.md
This single file contains full instructions and configuration for an autonomous ChatGPT agent to generate all required files
for a single-container, multi-version development Docker image of Shopware 6 (6.5/6.6/6.7).
-->

# 🧠 ChatGPT Agent Task: Build a Multi-Version Shopware 6 Dev Docker Image

## Overview

Your task is to generate a fully‑self‑contained **Docker development image** for **Shopware 6 plugin/theme development**, supporting versions **6.5.x**, **6.6.x**, and **6.7.x**, with all services running *inside the container*.  
The final output must include:

- `Dockerfile` (or base image)  
- `README.md`  
- `.github/workflows/build-and-push.yml` (GitHub Actions CI)  
- `.github/scripts/smoke-test.sh`

All files should be output in a **single pass**, with appropriate file path headers.

---

## ✅ Supported Shopware Version Tracks & System Stack

Create a single Dockerfile that dynamically configures services based on the `SHOPWARE_VERSION` build argument:

| Shopware Version Track | PHP Version              | Node Version                     | Redis      | Database Engine                                     | Elasticsearch               |
| ---------------------- | ------------------------ | -------------------------------- | ---------- | --------------------------------------------------- | --------------------------- |
| **6.5.x**              | PHP 8.1                  | Node 18.x                        | optional   | MariaDB 10.11+ or MySQL 8.0+ (avoid 8.0.20/21)      | Not required                |
| **6.6.x**              | PHP 8.2                  | Node 20.x                        | Redis 7.0+ | MariaDB 10.11+ or MySQL 8.0+ (avoid 8.0.20/21)      | Optional                    |
| **6.7.x**              | PHP 8.2–8.3/8.4 (tested) | Node 20.x (opt Node 22 override) | Redis 7.0+ | MySQL 8.0+ or MariaDB 10.11+ (avoid 10.11.5/11.0.3) | Elasticsearch 7.8+ required |

> Shopware system requirements summary: PHP version **>= 8.2 – <= 8.3**, MySQL 8 or MariaDB 10.11 (excluding specific broken patch versions), Redis 7+, Elasticsearch 7.8+; Node.js minimum **20.x** for later versions.  
> See: Shopware official docs :contentReference[oaicite:0]{index=0}

---

## 🎯 High-Level Requirements

- **Monolithic Docker image** (no external DB, redis, ES required).
- **Provenance**: Built via GitHub Actions; published to `ghcr.io/<org>/shopware-dev:<version>`.
- **Cross-platform file sharing**: UID/GID remapping, delegated volume mounts for macOS and Windows.
- **Xdebug enabled by default**, overrideable via `XDEBUG_ENABLED=0`.
- **Always uses latest patch version** of each minor track during CI builds. Needs logic (probably `composer create-project`) to fetch the latest patch.
- Include: MySQL/MariaDB, Redis server, Elasticsearch (or OpenSearch 7.x), Adminer, MailCatcher, watchers (`bin/watch-*.sh`).
- Use a lightweight process supervisor (e.g. `s6`, `supervisord`, or FrankenPHP/Caddy as combined runtime).
- Watchers, CLI tools, plugin/theme hot reloading support.
- Developer usage: mount local `./custom/plugins` (or themes) directory.

---

## 📦 Prompt For ChatGPT Agent

Copy the following block exactly into a ChatGPT session with Web Brows­ing enabled **or** into a local agent to generate all required files.

```text
You are a professional DevOps engineer experienced with Shopware 6. Date: **2025‑08‑02**.

Generate a **monolithic Docker development image** for Shopware 6 plugin/theme work, supporting version tracks **6.5.x**, **6.6.x**, and **6.7.x**. The image must run *all services* (Shopware, PHP, MySQL/MariaDB, Redis, Elasticsearch, Adminer, MailCatcher, asset watchers); nothing is external.

### Requirements:

1. **Dockerfile** (or minimal wrapper):
   - Accepts `ARG SHOPWARE_VERSION` (“6.5”, “6.6”, “6.7”).
   - Selects PHP version:
     - 6.5 → PHP 8.1,
     - 6.6 → PHP 8.2,
     - 6.7 → PHP 8.2 or 8.3/8.4.
   - Installs Node.js:
     - 6.5 → Node 18.x,
     - 6.6 & 6.7 → Node 20.x (and optionally 22.x via `NODE_VERSION` override).
   - Runs `composer create-project shopware/production:$VERSION` to pull latest patch.
   - Configures and runs:
     - MySQL or MariaDB (default: whichever Shopware recommends; allow `DB_ENGINE=mysql|mariadb`),
     - Redis 7.0+,
     - Elasticsearch 7.8+ (for 6.7.x; optional for 6.6).
     - Adminer UI (e.g. on port 8080),
     - MailCatcher or similar,
     - Asset watchers (`bin/watch-storefront.sh`, `bin/watch-administration.sh`).
   - Implements process supervision (e.g. `s6`, `supervisord`, or FrankenPHP/Caddy).
   - Handles `XDEBUG_ENABLED=1|0`, default on; allows disabling.
   - Accepts `ENV UID`, `GID`, remaps filesystem permissions for volume-mounted code (for macOS/Windows compatibility).
   - Optimizes layer caching for rebuilds.

2. **README.md**:
   - Show how to run one version locally:

     ```bash
     docker run --rm \
       -v $(pwd)/custom/plugins:/var/www/html/custom/plugins:delegated \
       -e SHOPWARE_VERSION=6.6 \
       -e DB_ENGINE=mariadb \
       -e NODE_VERSION=20 \
       -e XDEBUG_ENABLED=1 \
       -e UID=$(id -u) \
       -e GID=$(id -g) \
       -p 80:80 -p 8888:8888 -p 9998:9998 \
       -p 3306:3306 -p 9200:9200 \
       ghcr.io/<org>/shopware-dev:6.6
     ```
   - Define default credentials: `admin:shopware`.
   - URLs: `/`, `/admin`, watcher ports, Adminer, MailCatcher.
   - Explain overriding Node version (e.g. to use Node 22).
   - Explain patch upgrade (just change `SHOPWARE_VERSION` and re‑run).
   - Mounting strategy (delegated, consistent, etc.) for Windows/macOS.

3. **GitHub Actions workflow .github/workflows/build-and-push.yml**:
   - Matrix build over `SHOPWARE_VERSION: ["6.5", "6.6", "6.7"]`.
   - Always fetch latest patch version.
   - Build images tagged `ghcr.io/<org>/shopware-dev:${{ matrix.version }}`.
   - Use `docker/build-push-action@v5`, with layer cache.
   - Triggers:
     - push to `main` (build all),
     - tags matching `v6.5.*`, `v6.6.*`, `v6.7.*`,
     - scheduled nightly without branch/tag to rebuild patch updates.
   - Uses GitHub hosted runner with Docker.

4. **.github/scripts/smoke-test.sh**:
   - Spins up container for given version (e.g. `docker run --rm ...`).
   - Executes:
     - `bin/console system:info`,
     - `curl --fail http://localhost/`, `curl --fail http://localhost/admin`,
     - (optionally) queries Elasticsearch health endpoint.
   - Exit 0 on success, non-zero on any failure.

### Constraints:
- Use Shopware 6 official composer package to target latest patch.
- Avoid known-bad database versions: MySQL 8.0.20/8.0.21; MariaDB 10.11.5/11.0.3.
- Cross‑platform volume performance (macOS/Windows).
- Xdebug ON by default.
- Adminer should run on port 8080, MailCatcher on 1025 (or 1080).
- No persistent storage across runs is required.
- Assume no external license tokens are needed.

Provide all files at once, each prefixed with its relative path (e.g. `Dockerfile`, `README.md`, `.github/...`, etc.).
