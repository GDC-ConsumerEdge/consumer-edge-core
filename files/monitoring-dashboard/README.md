# Monitoring Dashboards

There are two subdirectories
- cnuc: Optimal metrics for CNUCs in GCP
- edge: Optimal metrics for edge servers or combination of edge servers and CNUCs

To import dashboards:

```bash
# NOTE: Running from project base directory, fix pathing if running from within the `scripts/` or other folders
scripts/post-provision/install-custom-dashboards.sh import ${PROJECT_ID} monitoring-dashboard/anthos-cluster-monitoring.json
```
