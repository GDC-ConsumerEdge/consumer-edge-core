# Overview
If you have reached here, it means you are looking to restore a volume/PV/PVC from a backup in a certain cluster . This quick guide will provide steps on how to achive that 

## Assumptions
- You have a old pod `my-data-pod`
- The pod has old pvc `my-pvc`
- The pvc is attached to old pv `my-pv`
- The pv is linked as old vol in longhorn `my-vol`
- The old vol backup to GCS has a snapshot `my-snap`



## Prerequisites
- The old vol `my-vol` has already been backup to GCS 
- The old vol backup snapshot is known. Notice you can find this either though an **API** or **GUI** . 
- The k8s job should be able run with escalatedPrivileges `allowPrivilegeEscalation: true`


## Steps to restore from old vol backup into a new vol
- The new vol to restore into is `my-vol-new`
- The new pv linked into the new restored vol is  `my-pv-new`
- The new pvc linked to new pv is `my-pvc-new`
- The k8s namespace to restore vol/pv/pvc into is `ns-new`
- Edit `restore-volume.yml` and update all the environment variables  
```
        env:
        - name: FROM_VOLUME_NAME
          value: my-vol
        - name: FROM_SNAPSHOT_NAME
          value: my-snap
        - name: TO_VOLUME_NAME
          value: my-vol-new
        - name: TO_PV_NAME
          value: my-pv-new
        - name: TO_PVC_NAME
          value: my-pvc-new
        - name: NAMESPACE
          value: ns-new
```
- Annotate the `restore-longhorn-volume-job` with the cluster-selector so that it only runs on the desired clusters 
```
apiVersion: batch/v1
kind: Job
metadata:
  name: restore-longhorn-volume-job
  annotations:
    configsync.gke.io/cluster-name-selector: cluster-1,cluster-2,cluster-3
```

- Drop the yml file in the root repo or desired store repo 
- Verify that the job is running either by directly looking at the logs or in cloud monitoring ` kubectl  logs -f restore-longhorn-volume-job-dxwfd`
We should observe a success message like following
```
Trying to find backup for volume, snapshot .. my-vol my-snap
Backup url to restore from  s3://abm-edge-backup-sekhrivijaytest16anthosbm@us/location-1?backup=backup-5cf8c2f8e5c14dc0&volume=my-vol
Creating a new volume from backup url ... my-vol-new
Waiting for volume to be created from backup
Creating a new PV with new volume my-pv-new
Creating a new PVC with new PV in namespace my-pvc-new ns-new
Successfully restored a new volume {'accessMode': 'rwo', 'backingImage': '', 'backupStatus': [], 'cloneStatus': {'snapshot': '', 'sourceVolume': '', 'state': ''}, 'conditions': {'restore': {'lastProbeTime': '', 'lastTransitionTime': '2021-11-24T22:33:09Z', 'message': '', 'reason': '', 'status': 'False'}, 'scheduled': {'lastProbeTime': '', 'lastTransitionTime': '2021-11-24T22:32:46Z', 'message': '', 'reason': '', 'status': 'True'}, 'toomanysnapshots': {'lastProbeTime': '', 'lastTransitionTime': '2021-11-24T22:32:46Z', 'message': '', 'reason': '', 'status': 'False'}}, 'controllers': [{'actualSize': '268435456', 'address': '', 'currentImage': '', 'endpoint': '', 'engineImage': 'longhornio/longhorn-engine:v1.2.2', 'hostId': '', 'instanceManagerName': '', 'isExpanding': False, 'lastExpansionError': '', 'lastExpansionFailedAt': '', 'lastRestoredBackup': '', 'name': 'test3-e-a0f7941f', 'requestedBackupRestore': '', 'running': False, 'size': '2147483648'}], 'created': '2021-11-24 22:32:45 +0000 UTC', 'currentImage': 'longhornio/longhorn-engine:v1.2.2', 'dataLocality': 'best-effort', 'dataSource': '', 'disableFrontend': False, 'diskSelector': None, 'encrypted': False, 'engineImage': 'longhornio/longhorn-engine:v1.2.2', 'fromBackup': 's3://abm-edge-backup-sekhrivijaytest16anthosbm@us/location-1?backup=backup-5cf8c2f8e5c14dc0&volume=my-vol', 'frontend': 'blockdev', 'kubernetesStatus': {'lastPVCRefAt': '2021-11-24T21:46:03Z', 'lastPodRefAt': '2021-11-24T21:46:03Z', 'namespace': 'ns-new', 'pvName': '', 'pvStatus': '', 'pvcName': 'mysql-pvc', 'workloadsStatus': [{'podName': 'mysql-c474db9ff-fv7zz', 'podStatus': 'Running', 'workloadName': 'mysql-c474db9ff', 'workloadType': 'ReplicaSet'}]}, 'lastAttachedBy': '', 'lastBackup': '', 'lastBackupAt': '', 'migratable': False, 'name': 'test3', 'nodeSelector': None, 'numberOfReplicas': 3, 'purgeStatus': None, 'ready': True, 'rebuildStatus': [], 'recurringJobSelector': None, 'replicaAutoBalance': 'ignored', 'replicas': [{'address': '', 'currentImage': '', 'dataPath': '/customer/replicas/test3-35a94729', 'diskID': 'c5df1bb2-948e-4e68-9254-0cf81d55fa1a', 'diskPath': '/customer', 'engineImage': 'longhornio/longhorn-engine:v1.2.2', 'failedAt': '', 'hostId': 'cnuc-1', 'instanceManagerName': '', 'mode': '', 'name': 'test3-r-0f0307f4', 'running': False}, {'address': '', 'currentImage': '', 'dataPath': '/customer/replicas/test3-3db956f6', 'diskID': '2483e78b-e89f-4c69-be70-f8e2a1ce3e61', 'diskPath': '/customer', 'engineImage': 'longhornio/longhorn-engine:v1.2.2', 'failedAt': '', 'hostId': 'cnuc-3', 'instanceManagerName': '', 'mode': '', 'name': 'test3-r-16fea159', 'running': False}, {'address': '', 'currentImage': '', 'dataPath': '/customer/replicas/test3-506265d2', 'diskID': 'fb117100-235d-41b8-9ed9-90b8ebb049f1', 'diskPath': '/customer', 'engineImage': 'longhornio/longhorn-engine:v1.2.2', 'failedAt': '', 'hostId': 'cnuc-2', 'instanceManagerName': '', 'mode': '', 'name': 'test3-r-1ddd6e9e', 'running': False}], 'restoreRequired': False, 'restoreStatus': [], 'revisionCounterDisabled': False, 'robustness': 'unknown', 'shareEndpoint': '', 'shareState': '', 'size': '2147483648', 'staleReplicaTimeout': 0, 'standby': False, 'state': 'detached'}
``` 



## Steps to restore from old vol backup into a same vol
- The new vol to restore into is `my-vol`
- The new pv linked into the new restored vol is  `my-pv`
- The new pvc linked to new pv is `my-pvc`
- The k8s namespace to restore vol/pv/pvc into is `ns`
- pod `my-data-pod` should be in `pending` state . If it is in terminating state, we will have to kill it first so that it can release the attached vol
- pv `my-pv` and pvc `my-pvc` must be deleted before restoring into same pv/pvc. Once the pod is deleted , the pv and pvc would also be deleted by itself. Notice we cannot restore into existing vol/pv/pvc if it exist already. The k8s job creates them from scratch . To delete manually , we can use **GUI** or **API**
- Edit `restore-volume.yml` and update all the environment variables like below. Notice all the new vol/pv/pvc are same as old 
```
        env:
        - name: FROM_VOLUME_NAME
          value: my-vol
        - name: FROM_SNAPSHOT_NAME
          value: my-snap
        - name: TO_VOLUME_NAME
          value: my-vol
        - name: TO_PV_NAME
          value: my-pv
        - name: TO_PVC_NAME
          value: my-pvc
        - name: NAMESPACE
          value: ns
```
- Follow the rest of the restore steps from above 