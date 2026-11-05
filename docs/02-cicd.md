# Phase 2: CI/CD with GitHub Actions

## What I Built
- A reusable platform workflow: [`.github/workflows/build-and-deploy.yml`](../.github/workflows/build-and-deploy.yml)
- A developer caller workflow that deploys each app in about 10 lines: [`.github/workflows/deploy.yml`](../.github/workflows/deploy.yml)
- Real CI checks: script linting, JSON→HCL generation, and `nomad job validate`, with the job spec published as an artifact

## Key Learnings
- `workflow_call` is the key to reusable pipelines
- GitHub only runs workflows from the repo's top-level `.github/workflows/` folder
- In a single repo, the caller uses a local path: `uses: ./.github/workflows/build-and-deploy.yml`
- Across repos, the same workflow is called as `owner/repo/.github/workflows/file.yml@ref`
- Developers only write 10 lines; the platform team maintains the complex logic
- A matrix calls the same reusable workflow once per app
- Version workflows with tags (v1, v2) to prevent breaking changes
- Use GitHub OIDC for secret management, not long-lived credentials

## Screenshots
![GitHub Actions Run](../screenshots/github-actions.png)
