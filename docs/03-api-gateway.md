# Phase 3: API Gateway (APISIX)

## What I Built
- Local APISIX cluster with etcd backend
- Automated route configuration via Admin API
- Rate limiting plugin enabled

## Key Learnings
- Since we use Nomad (not K8s), we use Admin API instead of Ingress Controller
- Routes should be stored as JSON in app repos — enables GitOps
- The Admin API must be firewalled — only CI/CD runners should access it
- Enforce route naming conventions (`/api/v1/{team}/{service}`) to prevent conflicts

## Screenshots
![APISIX Route Config](../screenshots/apisix-route.png)