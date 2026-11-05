# Platform Engineering Research: Self-Service Developer Platform Design

> **Document Type:** Research & Architecture Proposal  
> **Date:** October, 2026  
> **Prepared For:** Platform Engineering Leadership  
> **Prepared By:** Rofiat Ahmed Sholagberu
> **Status:** In progress
---

## 1. Executive Summary

This document outlines the research and proposed architecture for our first Platform Engineering initiative: building a **self-service developer platform**. The goal is to transition from a ticket-based operations model to a "Golden Path" self-service model, empowering developers to **deploy, expose, and monitor** their services with minimal friction and minimal manual intervention from the platform team.

The proposed technology stack consists of:

| Layer | Technology | Role |
| :--- | :--- | :--- |
| **Orchestration & Discovery** | Nomad + Consul | Deploy workloads and auto-register services |
| **CI/CD** | GitHub Actions | Standardized, reusable build & deploy pipelines |
| **API Gateway** | APISIX | Expose services securely with routing, SSL, rate limiting |
| **Observability** | Prometheus + Grafana | Auto-discovered metrics and out-of-the-box dashboards |

This research defines:
- The boundaries of **self-service** vs. **platform-managed** responsibilities
- Required **tooling and standardization** for each component
- **Risks, gaps, and open questions** to validate before implementation
- A **phased rollout plan** to mitigate risk

---

## 2. The "Golden Path" Workflow

The "Golden Path" represents the standardized, frictionless journey a developer takes to ship code. The proposed end-to-end workflow is:

```
┌──────────────┐
│ Developer    │
│ writes code  │
└──────┬───────┘
       │
       ▼
┌──────────────────────────────────────┐
│ GitHub Actions (Reusable Workflow)   │
│  • Build  • Test  • Package          │
└──────┬───────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────┐
│ Internal CLI Wrapper                 │
│  • Simple JSON → Nomad HCL           │
└──────┬───────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────┐
│ Nomad + Consul                       │
│  • Deploy workload                   │
│  • Auto-register in service catalog  │
└──────┬───────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────┐
│ APISIX (via Admin API)               │
│  • Route exposed securely            │
│  • Rate limits, CORS, SSL applied    │
└──────┬───────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────┐
│ Prometheus + Grafana                 │
│  • Auto-discovery via Consul SD      │
│  • Default dashboard provisioned     │
└──────────────────────────────────────┘
```

**Result:** A developer commits code and, within minutes, has a deployed, routed, and monitored service — without filing a single ticket.

---

## 3. Component Deep-Dives

### 3.1 Orchestration & Discovery: Nomad + Consul

**Objective:** Enable developers to deploy applications and rely on automatic service discovery without requiring deep expertise in Nomad HCL or Consul networking.

| Responsibility | Details |
| :--- | :--- |
| **Self-Service (Devs)** | Define application requirements (CPU, RAM, ports, env vars) using a simplified, standardized YAML/JSON template. |
| **Platform-Managed** | Maintain Nomad cluster health, manage Consul ACLs, define base networking, and manage underlying compute infrastructure. |
| **Standardization / Tooling** | **Internal CLI / Wrapper Script:** Since Nomad lacks a native package manager like Helm, we need a lightweight internal tool (e.g., `platform-cli deploy`) that takes simplified YAML and generates complex Nomad HCL on the fly. |
| **Risks & Gaps** | • **Nomad ACL Complexity:** Fine-tuning ACLs so devs can debug their jobs without cluster-admin privileges is difficult.<br>• **Templating Gap:** The platform team must build and maintain the HCL templating engine ourselves. |

**Proposed Self-Service Workflow:**
1. Developer writes a `platform-config.yaml` in their repo.
2. CI pipeline runs `platform-cli deploy --config platform-config.yaml`.
3. CLI generates HCL, submits to Nomad, and waits for health checks.
4. Consul automatically registers the service for discovery.

---

### 3.2 CI/CD: GitHub Actions

**Objective:** Provide standardized, secure, and reusable pipelines so developers spend time writing business logic, not YAML.

| Responsibility | Details |
| :--- | :--- |
| **Self-Service (Devs)** | Add a minimal (5–10 line) `.github/workflows/deploy.yml` file that simply "calls" the platform team's reusable workflow. |
| **Platform-Managed** | Maintain central reusable workflows, manage self-hosted GitHub Runners, and handle secure secret injection (e.g., via HashiCorp Vault). |
| **Standardization / Tooling** | • **Centralized Workflow Repo:** A dedicated repo containing versioned Reusable Workflows and Composite Actions.<br>• **OIDC Integration:** Use GitHub OIDC to authenticate with cloud providers / Vault, eliminating long-lived access keys. |
| **Risks & Gaps** | • **Breaking Changes:** If the platform team updates a central workflow and introduces a bug, it breaks every developer's pipeline. *Mitigation: Strict semantic versioning (`v1`, `v2`) for all central workflows.*<br>• **Runner Scaling:** Self-hosted runners may bottleneck during peak commit times. |

**Proposed Self-Service Workflow:**
```yaml
# Developer's entire CI/CD file
name: Deploy
on: [push]
jobs:
  deploy:
    uses: platform-team/workflows/.github/workflows/deploy.yml@v1
    with:
      app_name: "my-service"
```

---

### 3.3 API Gateway: APISIX

**Objective:** Allow developers to expose their APIs to the internet or internal consumers securely, without manual load balancer or gateway configuration.

| Responsibility | Details |
| :--- | :--- |
| **Self-Service (Devs)** | Define API routes, CORS policies, and service-specific rate limits in a configuration file within their application repository. |
| **Platform-Managed** | Manage the APISIX cluster, provision global SSL/TLS certificates, enforce global Web Application Firewall (WAF) rules, and set baseline rate limits. |
| **Standardization / Tooling** | **GitOps via Admin API:** Because we are using Nomad (not Kubernetes), we will **not** use the APISIX Ingress Controller. Instead, the GitHub Actions pipeline will read the dev's route config and push it to the APISIX Admin API automatically upon deployment. |
| **Risks & Gaps** | • **Route Conflicts:** Two developers might accidentally claim the same URL path. *Mitigation: Enforce strict namespace routing conventions (e.g., `/api/v1/{team}/{service}`).*<br>• **Admin API Security:** The APISIX Admin API must be strictly firewalled and only accessible by CI/CD runners. |

**Proposed Self-Service Workflow:**
1. Developer adds `apisix-routes.json` to their repo.
2. CI pipeline reads the file and calls `POST /apisix/admin/routes/{id}`.
3. APISIX updates its routing table in real time — zero downtime.

---

### 3.4 Observability: Grafana + Prometheus

**Objective:** Achieve "Observability as Code" where every service gets out-of-the-box dashboards and alerts the moment it is deployed.

| Responsibility | Details |
| :--- | :--- |
| **Self-Service (Devs)** | Integrate standard Prometheus client libraries into their application code to expose a `/metrics` endpoint. Define custom business-logic alerts if needed. |
| **Platform-Managed** | Manage the Prometheus / Grafana infrastructure, configure auto-discovery, and maintain "Default Dashboards" (CPU, Memory, HTTP 5xx rates). |
| **Standardization / Tooling** | • **Consul Service Discovery:** Configure Prometheus `consul_sd_configs` to automatically find new services registered in Consul and scrape them without manual config.<br>• **Dashboard Provisioning:** Use Terraform or Jsonnet to automatically generate and provision a default Grafana dashboard for every new service. |
| **Risks & Gaps** | • **Alert Fatigue:** If every service triggers default alerts for minor blips, developers will ignore them. *Mitigation: Platform team must define sensible default thresholds.*<br>• **High Cardinality:** Developers might accidentally expose metrics with too many unique labels, crashing Prometheus. *Mitigation: Enforce metric naming and label guidelines.* |

**Proposed Self-Service Workflow:**
1. Developer adds a Prometheus client library to their app.
2. Nomad registers the service in Consul with a `metrics_port` tag.
3. Prometheus auto-discovers the service via `consul_sd_configs`.
4. Grafana auto-provisions a dashboard using a Jsonnet template keyed on service name.

---

## 4. Capability Matrix Summary

| Component | Developer Self-Service | Platform-Managed | Key Tooling to Build |
| :--- | :--- | :--- | :--- |
| **Nomad + Consul** | Simplified YAML config | Cluster, ACLs, networking | JSON/YAML → HCL wrapper CLI |
| **GitHub Actions** | 5-line workflow caller | Reusable workflows, runners, OIDC | Central workflow repo (versioned) |
| **APISIX** | Route config in repo | Cluster, SSL, WAF, global policies | GitOps push via Admin API |
| **Prometheus + Grafana** | `/metrics` endpoint | Auto-discovery, default dashboards | `consul_sd_configs` + Jsonnet templates |

---

## 5. Implementation Phasing

To mitigate risk and deliver value quickly, the platform should be rolled out in three distinct phases:

### Phase 1: The Core "Golden Path" (Weeks 1–4)
- Deploy Nomad + Consul for orchestration and discovery
- Build the internal CLI / HCL wrapper
- Set up GitHub Actions reusable workflows and OIDC integration
- **Milestone:** *Developers can build and deploy a basic internal service autonomously.*

### Phase 2: External Exposure & API Management (Weeks 5–7)
- Deploy and configure the APISIX cluster
- Integrate APISIX Admin API into the GitHub Actions pipeline
- Implement global SSL, WAF, and routing conventions
- **Milestone:** *Developers can expose their services securely to the outside world.*

### Phase 3: Observability & Polish (Weeks 8–10)
- Configure Prometheus Consul Service Discovery
- Build and auto-provision default Grafana dashboards
- Establish standard alerting routing (e.g., Slack / PagerDuty)
- **Milestone:** *Full end-to-end self-service platform is operational.*

---

## 6. Key Risks & Mitigations

| Risk | Impact | Mitigation |
| :--- | :--- | :--- |
| Nomad ACL complexity blocks developer debugging | High | Build pre-defined least-privilege policies per namespace |
| Breaking change in reusable workflow breaks all pipelines | High | Strict semantic versioning + canary rollout |
| APISIX route conflicts between teams | Medium | Enforce `/api/v1/{team}/{service}` naming convention |
| Prometheus high-cardinality crash | Medium | Lint metrics in CI; enforce label guidelines |
| Alert fatigue | Medium | Sensible default thresholds; route alerts per team |
| Developer adoption is low | High | Interview 3–5 developers early; iterate on DevEx |

---

## 7. Conclusion & Next Steps

This research confirms that a self-service platform using **Nomad, GitHub Actions, APISIX, and Prometheus/Grafana** is highly viable and aligns with modern Platform Engineering principles. The key to success is not just the technology, but the **Developer Experience (DevEx)** — abstracting the complexity of infrastructure behind standardized templates and CI/CD automation.

The proposed architecture delivers on the core promise of Platform Engineering: **the right way becomes the easiest way.**

### Immediate Next Steps
1. **Leadership Review:** Review and approve this architectural proposal and phasing roadmap.
2. **Sandbox Provisioning:** Allocate infrastructure for a Phase 1 Proof of Concept (PoC) environment.
3. **Developer Discovery:** Interview 3–5 internal software engineers to validate the proposed "Golden Path" workflow, gather UX feedback, and ensure the tooling meets actual developer needs before writing production code.
4. **Phase 1 Kickoff:** Begin implementation of Nomad + Consul + GitHub Actions core.

---

## Appendix A: Glossary

| Term | Definition |
| :--- | :--- |
| **Golden Path** | The standardized, supported workflow for deploying a service |
| **Paved Road** | Synonym for Golden Path — the well-maintained, easy route |
| **DevEx** | Developer Experience — how easy/hard it is for devs to use the platform |
| **GitOps** | Managing infrastructure state via Git commits and automated sync |
| **OIDC** | OpenID Connect — secure, short-lived auth without long-lived secrets |
| **HCL** | HashiCorp Configuration Language — Nomad's config format |
| **Consul SD** | Consul Service Discovery — auto-finding services in a catalog |
| **High Cardinality** | Too many unique metric labels, causing Prometheus to run out of memory |

---

## Appendix B: References

- [HashiCorp Nomad Documentation](https://developer.hashicorp.com/nomad/docs)
- [HashiCorp Consul Documentation](https://developer.hashicorp.com/consul/docs)
- [GitHub Reusable Workflows](https://docs.github.com/en/actions/using-workflows/reusing-workflows)
- [Apache APISIX Admin API](https://apisix.apache.org/docs/apisix/admin-api/)
- [Prometheus Consul SD Config](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#consul_sd_config)
- [Grafana Provisioning](https://grafana.com/docs/grafana/latest/administration/provisioning/)

---

*End of Document*