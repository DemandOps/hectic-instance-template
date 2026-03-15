# Extension Review Checklist

Complete this before production activation of a custom extension.

- Manifest kind/scope/risk matches instance policy.
- Extension source lives in its own repo.
- Secrets are stored outside tracked files.
- Threat model is completed.
- Permissions have been minimized.
- Public routes and forms were reviewed for hostile input.
- Any uploads were reviewed for abuse handling.
- External API calls are documented.
- Unit or integration tests passed.
- Bundle was built from the reviewed source revision.
- Staging install and validation passed.
- Production activation was explicitly approved.
