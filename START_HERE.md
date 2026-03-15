# START HERE

Give this file to Codex or Claude Code when setting up or operating this Hectic instance.

## Mission

Take this repo from configuration to a working Hectic installation.

The target outcome is:

- core Hectic deployed on the target Linux host
- admin access working
- app, admin, and API health checks passing
- outbound email configured
- optional first-party extensions installed only if licensed
- no secrets written into tracked files

## Read These Files First

1. `hectic.instance.yaml`
2. `scripts/read-instance-config.sh`
3. `agents/bootstrap.md`
4. `extensions/desired-state.yaml`
5. `deploy/README.md`
6. `.github/workflows/production.yml`
7. `branding/site.json`
8. `security/extension-threat-model.md`
9. `security/review-checklist.md`
10. `docs/INSTANCE_AND_EXTENSION_LIFECYCLE.md` in the public core repo when custom extension work is involved

## Default Rules

- This repo is the deployment control plane for one live Hectic installation.
- Do not change Hectic core source code from this repo.
- Do not write secrets into git-tracked files.
- Do not change the pinned core version unless explicitly asked.
- Do not activate paid extensions without a valid license.
- Do not activate self-built extensions before the threat model and review checklist are complete.
- Do not use the generic runtime for privileged auth or connector extensions.

## What You Should Do

1. Read `hectic.instance.yaml` and understand the desired state.
2. Run `scripts/read-instance-config.sh hectic.instance.yaml` and confirm the parsed host, domains, pinned artifact refs, email provider, and storage provider.
3. Check that the required repository or environment secrets exist.
4. Bootstrap the Linux host if needed.
5. Deploy the pinned Hectic core release.
6. Verify:
   - app health
   - admin health
   - API health
   - admin login
   - outbound email
7. Create the first admin user if needed.
8. Create the primary workspace if needed.
9. Review `extensions/desired-state.yaml`.
10. Install, validate, configure, and activate any licensed extensions that are requested.
11. Apply branding overrides from `branding/site.json`.
12. Report what changed, what is still missing, and any risks.

## Required Inputs

You may need:

- SSH access to the Linux host
- DNS already pointing at the host
- outbound email credentials for the selected provider
- object storage credentials when using `s3-compatible` storage
- admin email address
- paid extension refs or license grants

## Repo Model

For most customers, this instance repo is the only private repo they need.

A second repo is needed only if the customer is building a custom extension with real logic. Simple branding and configuration changes stay here.

## Success Conditions

The task is complete when:

- the pinned core version is running
- the health checks pass
- admin access works
- outbound email works
- this repo accurately reflects the deployed desired state
- any installed extension has passed the required review gates
