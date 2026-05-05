# Design Spec: Sed-to-Awk/Yq Refactoring for macOS Compatibility

## Status
Proposed

## Context
The `scripts/instance-context.sh` script uses `sed -i` extensively for in-place file modifications. This command is incompatible between macOS (BSD sed) and Linux (GNU sed) because the `-i` flag requires an extension argument on macOS. Instead of using a wrapper function, we will refactor the script to use `awk` (for text/bash files) and `yq` (for YAML files) to ensure cross-platform compatibility and more robust file manipulation.

## Goals
- Eliminate all usage of `sed -i` in `scripts/instance-context.sh`.
- Use `awk` for line insertions and replacements in `.envrc` (Bash).
- Use `yq` (mikefarah/yq v4) for all modifications to YAML files (`inventory.yaml`, `instance-run-vars.yaml`, etc.), leveraging its comment-preservation capabilities.
- Ensure the script remains functional on both macOS and Linux.

## Proposed Changes

### 1. `.envrc` Modifications (Text/Bash)
All `sed -i` replacements in `envrc` will be converted to `awk` with a temporary file.

**Pattern: Replacement**
- **From:** `sed -i "s/pattern/replacement/" "$file"`
- **To:** `awk '{gsub(/pattern/, "replacement")}1' "$file" > "$file.tmp" && mv "$file.tmp" "$file"`

**Pattern: Insertion at Line 1**
- **From:** `sed -i "1i # Comment" "$file"`
- **To:** `awk 'BEGIN{print "# Comment"}1' "$file" > "$file.tmp" && mv "$file.tmp" "$file"`

### 2. YAML Modifications (YAML)
All `sed -i` string replacements in YAML will be converted to native `yq` commands.

**Pattern: Field Update**
- **From:** `sed -i "s@^field:.*@field: \"value\"@" "$file"`
- **To:** `yq e -i ".field = \"value\"" "$file"`

**Pattern: Line Comments**
- **From:** `sed -i "/key: \"val\"/s/$/ # Comment/" "$file"`
- **To:** `yq e -i ".key line_comment=\"Comment\"" "$file"`

**Pattern: Uncommenting/Creating Optional Fields**
- **From:** `sed -i "s@^# optional_field:.*@optional_field: \"value\"@" "$file"`
- **To:** `yq e -i ".optional_field = \"value\"" "$file"`

### 3. Implementation Details

#### `dehydrate_context`
Replace token scrubbing:
```bash
# Scrub envrc with awk
awk -v closed="$closed" '{
    gsub(/.*SCM_TOKEN_USER=.*/, "export SCM_TOKEN_USER=\""closed"\"");
    gsub(/.*SCM_TOKEN_TOKEN=.*/, "export SCM_TOKEN_TOKEN=\""closed"\"");
    gsub(/.*OIDC_CLIENT_ID=.*/, "export OIDC_CLIENT_ID=\""closed"\"");
    gsub(/.*OIDC_CLIENT_SECRET=.*/, "export OIDC_CLIENT_SECRET=\""closed"\"");
    print
}' "$target_dir/envrc" > "$target_dir/envrc.tmp" && mv "$target_dir/envrc.tmp" "$target_dir/envrc"
```

#### `generate_context`
Convert the large block of `sed` updates for `envrc` and `inventory.yaml` into sequential `awk` and `yq` calls.

#### `ingest_context`
Convert the `configs/${name}-config.yaml` generation to strictly use `yq`.

## Verification Plan
1. **Syntax Check**: Run `bash -n scripts/instance-context.sh`.
2. **Context Creation**: Run `./scripts/instance-context.sh -r us-west1 -g configs/cascade-config.yaml cascade`. Verify `envrc`, `inventory.yaml`, and `instance-run-vars.yaml` are correctly populated.
3. **Hydration/Dehydration**: Run `./scripts/instance-context.sh -o` and `./scripts/instance-context.sh -x`. Verify tokens are correctly injected and scrubbed in `.envrc`.
4. **macOS Simulation**: If possible, verify that `awk` and `yq` commands use POSIX-compliant flags supported by both BSD and GNU versions (Note: `mikefarah/yq` is a Go binary and is consistent across platforms).
