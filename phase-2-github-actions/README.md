# Phase 2: CI/CD with GitHub Actions

GitHub only runs workflows from the repository's top-level `.github/workflows/` folder, so the Phase 2 workflows live there:

| File | Role |
|------|------|
| [`.github/workflows/build-and-deploy.yml`](../.github/workflows/build-and-deploy.yml) | **Platform team:** reusable `workflow_call` pipeline |
| [`.github/workflows/deploy.yml`](../.github/workflows/deploy.yml) | **Developer:** the short caller that deploys each app |

## What the pipeline does

1. **Validate inputs:** `app_name` format, and that it matches the app's JSON config
2. **Lint:** `bash -n` and `shellcheck` on every platform script
3. **Build:** installs Nomad, runs `generate-hcl.sh --dry-run`, and validates the job with `nomad job validate`
4. **Publish:** uploads the generated `.nomad.hcl` as a build artifact
5. **Deploy (dry run):** writes the job spec to the run summary. GitHub-hosted runners cannot reach the lab's local Nomad, so the real deploy runs locally with `golden-path.sh`

## Adding an app

Add one entry to the matrix in `deploy.yml`:

```yaml
- app_name: my-new-app
  config_file: path/to/my-new-app.json
```

## Triggers

- Push to `main` that touches `lib/`, `phase-1-nomad-consul/`, `phase-5-golden-path/` or `.github/workflows/`
- Pull requests to `main`
- Manual: **Actions → Deploy Apps → Run workflow**
