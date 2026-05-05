# Design Spec: Optional OIDC Settings in Instance Context

This spec defines changes to `scripts/instance-context.sh` to make OIDC settings optional during the ingestion and hydration processes.

## Problem
Currently, the `instance-context.sh` script assumes OIDC settings (Client ID and Secret) are always present or at least handles them the same way as required variables. During ingestion, it might capture commented-out lines from `envrc` and push them to GSM. During hydration, it doesn't gracefully handle missing OIDC secrets, often leaving placeholder or "closed" values in `envrc` instead of commenting them out.

## Goals
- **Ingestion (-i):** Only ingest OIDC settings into GSM if they are actively exported (not commented out) in `envrc`.
- **Hydration (-o):** If OIDC settings are missing from GSM, comment them out in `envrc` and set `OIDC_ENABLED="false"`. If present, uncomment them and set `OIDC_ENABLED="true"`.
- **Dehydration (-x):** Preserve the commented-out state of OIDC settings while masking their values.

## Proposed Changes

### 1. Ingestion (`ingest_context`)
Modify the variable extraction to use `grep "^export "` to ensure only active exports are captured.

```bash
# Before
local oidc_id=$(grep "export OIDC_CLIENT_ID=" "$target_dir/envrc" | cut -d'"' -f2)
local oidc_secret=$(grep "export OIDC_CLIENT_SECRET=" "$target_dir/envrc" | cut -d'"' -f2)

# After
local oidc_id=$(grep "^export OIDC_CLIENT_ID=" "$target_dir/envrc" | cut -d'"' -f2)
local oidc_secret=$(grep "^export OIDC_CLIENT_SECRET=" "$target_dir/envrc" | cut -d'"' -f2)
local oidc_user=$(grep "^export OIDC_USER=" "$target_dir/envrc" | cut -d'"' -f2)
```

### 2. Hydration (`hydrate_context`)
Update the `awk` injection logic to toggle the commented-out state and update `OIDC_ENABLED`.

```bash
# New logic inside awk
if ($0 ~ /OIDC_CLIENT_ID=/) {
    if (oidc_i != "") $0 = "export OIDC_CLIENT_ID=\""oidc_i"\""
    else $0 = "# export OIDC_CLIENT_ID=\"\""
}
if ($0 ~ /OIDC_CLIENT_SECRET=/) {
    if (oidc_s != "") $0 = "export OIDC_CLIENT_SECRET=\""oidc_s"\""
    else $0 = "# export OIDC_CLIENT_SECRET=\"\""
}
if ($0 ~ /OIDC_USER=/) {
    if (oidc_u != "") $0 = "export OIDC_USER=\""oidc_u"\""
    else $0 = "# export OIDC_USER=\"\""
}
if ($0 ~ /OIDC_ENABLED=/) {
    if (oidc_i != "" && oidc_s != "") $0 = "export OIDC_ENABLED=\"true\""
    else $0 = "export OIDC_ENABLED=\"false\""
}
```

### 3. Dehydration (`dehydrate_context`)
Update the masking logic to preserve the comment prefix if it exists.

```bash
# New logic inside awk
if ($0 ~ /OIDC_CLIENT_ID=/ || $0 ~ /OIDC_CLIENT_SECRET=/ || $0 ~ /OIDC_USER=/) {
    prefix = ($0 ~ /^#/) ? "# " : ""
    var_name = ($0 ~ /OIDC_CLIENT_ID/) ? "OIDC_CLIENT_ID" : ($0 ~ /OIDC_CLIENT_SECRET/) ? "OIDC_CLIENT_SECRET" : "OIDC_USER"
    $0 = prefix "export " var_name "=\"" closed "\""
}
```

## Success Criteria
- Ingesting a folder with `# export OIDC_CLIENT_ID="..."` does NOT create a secret in GSM.
- Hydrating a context that lacks OIDC secrets in GSM results in `envrc` having:
  ```bash
  # export OIDC_CLIENT_ID=""
  # export OIDC_CLIENT_SECRET=""
  export OIDC_ENABLED="false"
  ```
- Hydrating a context WITH OIDC secrets results in:
  ```bash
  export OIDC_CLIENT_ID="actual-id"
  export OIDC_CLIENT_SECRET="actual-secret"
  export OIDC_ENABLED="true"
  ```
- Dehydrating preserves the `# ` prefix if it was already commented out.
