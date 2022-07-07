# Overview

Metadata is created during the install/creation of a cluster using `bmctl`. This metadata (folders/files) are important to upgrade/update execution and should be backedup.

## Process

### Rules
* Many snapshots can exist at one point for an active cluster
* When `all-remove-abm-software.yaml` playbook is run, indicates that the `inventory` of that playbook is to be removed, this will trigger all snapshots to be **archived**.


### Scenarios

* Initial provisioning phase (when the cluster is not present and gke-hub has no registration),

    1. Successfully complete `bmctl create`
    1. Run "snapshot" capture the contents of state in `{{ abm_workspace_folder }}`. See [official documentation](https://cloud.google.com/anthos/clusters/docs/bare-metal/latest/troubleshooting/bmctl-snapshot)

<!-- NOTE: /var/keys/gsa-key.json is "magic", variables in `google-tools` are used to set this key. Need to move to global scope varaible if want to use variables -->
        ```
        # Runt he snapshot tool to collect compressed folder of `bmctl-workspace`
        bmctl check cluster --snapshot \
            --snapshot-config {{ snapshot_config_file }} \
            --cluster {{ cluster_name }} \
            --service-account-key-file /var/keys/gsa-key.json \
            --snapshot-output {{ snapshot_output_file }}  \
            --kubeconfig {{ kubeconfig_shared_location }}
        ```

    1. Upload the compressed file `{{ snapshot_output_file }}` to `{{ snapshot_gcs_bucket_base }}` (if variable has been defined)

* After provisioning (existing `snapshot` has been saved)

    1. Remove the `{{ snapshot_output_file }}`
    1. Download the `.tar.gz` backup file from the GCS bucket to `{{ snapshot_output_file }}` location
    1. Un-compress the file into a folder on the filesystem
    1. Change directory into the containing created folder
      * NOTE: Current bug (b/238099655) detailing containing folder is not the same name as the `.tar.gz` compressed file
    1. Run `bmctl cluster update` or `bmctl cluster upgrade` as desired using the contained folder as a root


* Remove cluster(s) from fleet/org

    1. Run playbook `all-remove-abm-software` to remove Cluster(s) from project(s)
    1. Moves all of the matching `{{ cluster_name }}` cluster's snapshots contained in `{{ snapshot_gcs_bucket_base }}`

## Naming Convention

In order to store all of the configuration in a GCS bucket and avoid conflicts, a naming convention will be used:

    ```
    <uniqueness-cluster-name>-cluster-snapshot-<simple-date-format>.tar.gz
    ```

    * Prefix with the `uniqueness` name given to the cluster (as of 07/01/2022, this is the `cluster_name` using `{{ cluster_name }}` in the `host_vars/<host>.yml`)
    * `cluster-config` - to identify the type of stored file
    * date-format in `YYYY-MM-DDTHH:mm:ssZ` format (Four-digit Year, Two digit Month, two-digit Date, "T", two-digit Hour, two-digit Minute, two-digit second with UTZ Timezone)
      * Save all formats in UTC time for simplicity