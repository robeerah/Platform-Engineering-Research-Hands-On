# Phase 4: Observability (Prometheus + Grafana)

## What I Built
- Prometheus with Consul Service Discovery (`consul_sd_configs`)
- Grafana with auto-provisioned dashboard
- Auto-discovery of Nomad-registered services

## Key Learnings
- `consul_sd_configs` is the magic — no manual target config needed
- When Nomad scales a service to 3 instances, Prometheus auto-finds all 3
- Use Grafana provisioning (JSON/YAML) to auto-create dashboards per service
- Watch out for high cardinality — enforce metric label guidelines

## Screenshots
![Grafana Dashboard](../screenshots/grafana-dashboard.png)
![Prometheus Targets](../screenshots/prometheus-targets.png)