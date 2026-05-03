# Design Spec: GCS Distributed Lock for Certificate Rotation

## Status
Proposed

## Context
The Kubernetes cluster nodes (3 nodes) need to perform a cluster-wide certificate rotation. Running this operation simultaneously on multiple nodes could lead to race conditions, corrupted configurations, or API server instability. 

We need a "leader election" or distributed locking mechanism to ensure exactly one node performs the rotation at a time. The script should run automatically on a schedule, staggered across the nodes to further reduce collision probability.

## Requirements
- **Mutual Exclusion**: Only one node can hold the lock.
- **Atomicity**: Lock acquisition must be race-condition safe using `gcloud storage` preconditions.
- **Deadlock Prevention**: Automatically recover from crashed lock-holders via a Time-To-Live (TTL).
- **Cluster Isolation**: Locks must be specific to each cluster to avoid collisions in shared buckets.
- **Scheduling**: Run via Cron every 3 months in a 1 AM - 3 AM window.
- **Staggered Execution**: Automate a 1-minute execution stagger across the cluster nodes.
- **Fast-Execution Prevention**: Add a 5-minute sleep at the end of the script to hold the lock past the 1-minute stagger window, preventing subsequent nodes from also running the rotation if the first node finishes too quickly.

## Proposed Architecture

### 1. Storage Backend & Atomic Locks
Uses the existing GCS bucket (`snapshot_gcs_bucket_base`). Node uses `gcloud storage cp ... --header="x-goog-if-generation-match: 0"` to atomically claim the lock `gs://<bucket>/<cluster-name>-cert-rotation.lock`.

### 2. Lock Life-cycle & TTL
1. Node attempts to create the lock.
2. If failed, it checks the lock object's timestamp. If `current_time - lock_time > TTL`, it deletes the stale lock and retries.
3. If successful, it runs rotation. 
4. The script sleeps for 5 minutes before exiting to ensure it outlasts the cron stagger of the other nodes.
5. A `trap` deletes the lock upon exit.

### 3. Cron Scheduling & Staggering
The cron job will be templated via Ansible. It will use the node's index in the Ansible inventory to stagger the minute of execution. 
- Node 0: `0 2 * */3 *` (2:00 AM)
- Node 1: `1 2 * */3 *` (2:01 AM)
- Node 2: `2 2 * */3 *` (2:02 AM)

## Detailed Design

### Configuration Changes (`inventory/group_vars/all.yaml`)
Update the variables to include the TTL and Cron settings:

```yaml
###
### Global Snapshot & Update Variables
###
snapshot_gcs_bucket_base: "{{ lookup('env', 'SNAPSHOT_GCS') | default( [ google_project_id, '-', cluster_name, '-snapshot' ] | join, True) }}"

# Distributed lock TTL for cluster-wide operations (e.g. cert rotation)
# Prevents deadlocks if a script fails to release the lock.
cert_rotation_lock_ttl_hours: 2

# Certificate Rotation Cron Schedule
# Default runs every 3 months at 2 AM (satisfies 1 AM - 3 AM window requirement)
cert_rotation_cron_months: "*/3"
cert_rotation_cron_hour: "2"
```

### Cron Template (`roles/abm-post-install/templates/rotate-k8s-certs-cron.sh.j2`)
We will replace the existing static cron with one that calculates the minute based on the host index:

```jinja2
{% set node_index = play_hosts.index(inventory_hostname) | default(0) %}
{{ node_index % 60 }} {{ cert_rotation_cron_hour }} * {{ cert_rotation_cron_months }} * runuser -l '{{ ansible_user }}' -c '{{ abm_install_folder }}/scripts/rotate-k8s-certs.sh' >> '{{ abm_install_folder }}/scripts/rotate-certs.log 2>&1'
```

### Script Logic (Pseudo-code)

```bash
LOCK_URI="gs://${BUCKET}/${CLUSTER}-cert-rotation.lock"
TTL_SECS=$((TTL_HOURS * 3600))

# 1. Attempt Acquisition
acquire() {
  gcloud storage cp /tmp/info "${LOCK_URI}" --header="x-goog-if-generation-match: 0"
}

# 2. TTL Check
is_stale() {
  UPDATED=$(gcloud storage objects describe "${LOCK_URI}" --format="value(updated)")
  # Calculate age...
  [[ $AGE -gt $TTL_SECS ]]
}

# 3. Main Loop
if ! acquire; then
  if is_stale; then
    gcloud storage rm "${LOCK_URI}"
    acquire || exit 0
  else
    echo "Lock held by another node."
    exit 0
  fi
fi

trap 'gcloud storage rm "${LOCK_URI}"' EXIT

# ... Run User's Rotate Certs Logic ...

# Prevent subsequent staggered cron jobs from picking up a prematurely released lock
echo "Rotation complete. Sleeping 5 minutes to bridge the stagger window before releasing lock..."
sleep 300
```

## Verification Plan
1. **Cron Validation**: Verify the rendered `/etc/cron.d/rotate-k8s-certs-cron.sh` files on the 3 nodes have staggered minutes (0, 1, 2).
2. **Locking Test**: Execute the script manually simultaneously on multiple nodes to verify only one acquires the lock.
3. **TTL Test**: Manually create a lock with an old timestamp and verify a node can "take over" after the TTL expires.
