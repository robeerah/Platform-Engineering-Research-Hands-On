# Platform Engineering Lab: Self-Service Developer Platform

A hands-on implementation of a self-service developer platform using **Nomad + Consul**, **GitHub Actions**, **APISIX**, and **Prometheus + Grafana**.

>  This project was completed as part of my Platform Engineering internship research.

##  What This Demonstrates

This lab proves that developers can **deploy, expose, and monitor** their services with minimal platform team intervention — the core philosophy of Platform Engineering.

##  Architecture

```
Developer Code
      ↓
GitHub Actions (CI/CD)
      ↓
┌─────────────────────────────────────────┐
│  Internal CLI Wrapper (JSON → HCL)      │
└─────────────────────────────────────────┘
      ↓
Nomad (Orchestration) + Consul (Discovery)
      ↓
APISIX (API Gateway) → Public URL
      ↓
Prometheus (Auto-Discovery) → Grafana Dashboard
```

##  Project Structure

| Phase | Directory | What You'll Learn |
|-------|-----------|-------------------|
| 1 | `phase-1-nomad-consul/` | Orchestration, service discovery, JSON→HCL templating |
| 2 | `.github/workflows/` ([notes](phase-2-github-actions/README.md)) | Reusable workflows, platform pipeline vs. developer caller |
| 3 | `phase-3-apisix/` | Admin API, GitOps routing, rate limiting |
| 4 | `phase-4-monitoring/` | Consul service discovery in Prometheus |
| 5 | `phase-5-golden-path/` | End-to-end automation script |

##  Quick Start

### Prerequisites (Windows 11 + Git Bash)

| Tool | How |
|------|-----|
| `nomad.exe`, `consul.exe` | Download the Windows binaries and place them in the repo root |
| `jq` | PowerShell: `winget install jqlang.jq`, then open a new Git Bash window |
| Docker Desktop | Used only for APISIX, etcd, Prometheus and Grafana |

Nomad runs natively with the `raw_exec` driver; apps are PowerShell processes that read their port from `$env:NOMAD_PORT_http`.

### Run the Full Golden Path

Terminal 1 (Git Bash, repo root):
```bash
./consul.exe agent -dev -ui
```

Terminal 2 (Git Bash, repo root):
```bash
./nomad.exe agent -dev -config=nomad-dev.hcl
```

Terminal 3 (Git Bash, repo root):
```bash
(cd phase-3-apisix && docker compose up -d)
(cd phase-4-monitoring && docker compose up -d)
./phase-5-golden-path/golden-path.sh phase-5-golden-path/app-config.json
```

Each phase can also be run on its own:
```bash
./phase-1-nomad-consul/generate-hcl.sh phase-1-nomad-consul/simple-config.json --dry-run
./phase-1-nomad-consul/generate-hcl.sh phase-1-nomad-consul/simple-config.json
./phase-3-apisix/setup-routes.sh my-webapp
```

Then visit:
- **App (via APISIX):** http://127.0.0.1:9080/api/v1/golden-app/test
- **App metrics:** http://127.0.0.1:9080/api/v1/golden-app/metrics
- **Grafana:** http://127.0.0.1:3000 (admin/admin)
- **Prometheus targets:** http://127.0.0.1:9090/targets
- **Consul:** http://127.0.0.1:8500
- **Nomad:** http://127.0.0.1:4646

### Tear down
```bash
./nomad.exe job stop -purge golden-app
./nomad.exe job stop -purge my-webapp
(cd phase-3-apisix && docker compose down)
(cd phase-4-monitoring && docker compose down)
```

##  Deep-Dive Documentation

Each phase has its own documentation with learnings and screenshots:
- [Phase 1: Orchestration](docs/01-orchestration.md)
- [Phase 2: CI/CD](docs/02-cicd.md)
- [Phase 3: API Gateway](docs/03-api-gateway.md)
- [Phase 4: Observability](docs/04-observability.md)
- [Phase 5: Golden Path](docs/05-golden-path.md)

##  Key Learnings

1. **Abstraction is everything** — The JSON→HCL wrapper saves developers from learning Nomad
2. **Reusable workflows** — Developers write 10 lines of CI/CD, not 100
3. **GitOps for gateways** — Routes live in app repos, pushed via Admin API
4. **Auto-discovery** — Prometheus finds services via Consul, no manual config
5. **The Golden Path** — One script deploys, routes, and monitors a service

##  Related Research

See the full research proposal: [Platform Engineering Research Doc](./RESEARCH-DOC.md)

##  Date
October 2026