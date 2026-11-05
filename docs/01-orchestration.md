# Phase 1: Orchestration & Discovery

## What I Built
- Local Nomad + Consul cluster
- Deployed `hashicorp/http-echo` as a test service
- Built a JSON-to-HCL wrapper script simulating an internal CLI

## Key Learnings
- Nomad lacks a Helm-like package manager, so templating must be custom-built
- Consul service discovery works automatically when Nomad registers services
- ACLs are the biggest complexity — devs need job-level access, not cluster-level

## Screenshots
![Nomad UI](../screenshots/nomad-ui.png)
![Consul UI](../screenshots/consul-ui.png)