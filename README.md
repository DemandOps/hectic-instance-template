# Hectic Instance Template

This tree is the canonical Hectic instance-template layout.

In the source repo, it is the upstream export source for the published
`DemandOps/hectic-instance-template` repository. In the published template repo,
this same tree is the canonical customer deployment-control-plane starting
point.

A private instance repo is the deployment control plane for one live Hectic installation. It should contain desired state, deployment policy, branding, and extension configuration. It should not contain a long-lived fork of the core source tree.

## What This Repo Is

This repo is:

- a public template repo
- the starting point for private instance repos such as `acme/hectic-prod`
- the canonical home for the deployment-control-plane shape customers should use

This repo is not:

- the public core repo
- a live DemandOps or customer instance
- a place to store secrets
- a place to author first-party paid extension source

## Next Proof Step

Use this repo to create or update:

- `DemandOps/hectic-staging`
- `DemandOps/hectic-prod`

Then prove the deployment model from those private instance repos rather than
from the core repo.

## Intended Use

1. Create a private repo from this template structure.
2. Fill in `hectic.instance.yaml`.
3. Add repository and environment secrets.
4. Open the repo in Codex or Claude Code.
5. Point the agent at `START_HERE.md`.
6. Let the agent deploy and operate the instance.
7. Use `scripts/read-instance-config.sh` to validate and inspect the non-secret desired state.

See also:

- [Customer Instance Setup](https://github.com/DemandOps/hectic/blob/main/docs/CUSTOMER_INSTANCE_SETUP.md)
- [Customer FAQ](https://github.com/DemandOps/hectic/blob/main/docs/CUSTOMER_FAQ.md)
- [Customer Onboarding Review](https://github.com/DemandOps/hectic/blob/main/docs/CUSTOMER_ONBOARDING_REVIEW.md)
- [Release Artifact Contract](https://github.com/DemandOps/hectic/blob/main/docs/RELEASE_ARTIFACT_CONTRACT.md)

## Contents

- `hectic.instance.yaml`
  Canonical desired state for one Hectic installation.
- `START_HERE.md`
  Single-file handoff for Codex or Claude Code.
- `agents/bootstrap.md`
  The first-run instructions an agent should follow.
- `branding/site.json`
  Customer-owned branding and copy overrides.
- `extensions/desired-state.yaml`
  Installed and planned extension refs.
- `.github/workflows/`
  Deployment and verification workflows owned by the instance repo.
- `deploy/`
  Deploy scripts, service units, and host bootstrap assets owned by the instance repo.
- `security/`
  Threat-model and review materials for custom extensions.
- `scripts/read-instance-config.sh`
  Canonical parser and validator for `hectic.instance.yaml`.

## Operating Rules

- Pin core releases instead of tracking arbitrary commits.
- Pin extension artifact refs instead of storing proprietary extension source here.
- Store custom extension source in separate repos.
- Keep customer-specific secrets in GitHub Actions secrets or another secret manager, not in this repo.
- Keep hosts, domains, artifact refs, buckets, and provider choices in `hectic.instance.yaml`.
- Default to one private instance repo only. Add a custom extension repo only when you are building custom extension logic.

## Export Status

This tree already includes the deployment workflows, deploy assets, and config
reader needed to materialize a working instance-template repo layout without
manual copying.

You can materialize that repo layout locally with:

```bash
scripts/export-instance-template.sh /absolute/path/to/hectic-instance-template
```

Validate it before or after export with:

```bash
make validate-instance-template
```
