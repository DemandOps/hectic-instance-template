# Agent Bootstrap Instructions

Use this file when onboarding a fresh Hectic instance.

`START_HERE.md` is the primary agent handoff. This file provides the more detailed execution checklist behind that handoff.

## Goal

Take a new customer from an empty Linux host to a working Hectic instance with:

- core deployed
- admin access created
- health checks passing
- outbound email configured
- optional paid extensions installed and activated when licensed

## Required Inputs

- SSH access to the Linux host
- domain names for `app`, `admin`, and `api`
- storage credentials
- outbound email credentials
- admin email address
- any purchased extension refs or local bundle files

## Workflow

1. Read `hectic.instance.yaml`.
2. Run `scripts/read-instance-config.sh hectic.instance.yaml` and confirm the parsed values.
3. Read `START_HERE.md`.
4. Confirm the pinned core artifact refs and target host.
5. Bootstrap the host with the deploy assets.
6. Configure runtime secrets outside git.
7. Deploy the pinned core release.
8. Verify:
   - app health endpoint
   - GraphQL availability
   - admin login flow
   - outbound email delivery
9. Create the admin user if needed.
10. Create the primary workspace if needed.
11. Review `extensions/desired-state.yaml`.
12. Install any licensed extensions.
13. Run the extension threat model and review checklist before activation.
14. Apply branding overrides from `branding/site.json`.
15. Enable public routes only after review gates pass.
16. Report the final state, gaps, and risks.

## Guardrails

- Do not change the pinned core version unless explicitly asked.
- Do not activate paid extensions without a valid license grant.
- Do not activate self-built extensions before the threat-model and review checklist are complete.
- Do not use the generic runtime for privileged auth or connector extensions.
- Do not write secrets into tracked files.
- Keep custom app source code in separate repos unless the customization is a simple content override.
- Default to one private instance repo only. Introduce a second repo only when building a custom extension with real logic.
