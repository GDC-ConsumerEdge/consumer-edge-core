import longhorn
import common
import os

FROM_VOLUME_NAME = os.getenv('FROM_VOLUME_NAME')
FROM_SNAPSHOT_NAME = os.environ.get('FROM_SNAPSHOT_NAME')
TO_VOLUME_NAME = os.getenv('TO_VOLUME_NAME', FROM_VOLUME_NAME)
TO_PV_NAME = os.getenv('TO_PV_NAME', FROM_VOLUME_NAME)
TO_PVC_NAME = os.getenv('TO_PVC_NAME', FROM_VOLUME_NAME)
NO_OF_REPLICAS = int(os.getenv('NO_OF_REPLICAS', 3))
NAMESPACE = os.getenv('NAMESPACE', 'default')

assert FROM_VOLUME_NAME != None and FROM_VOLUME_NAME.strip() != '', 'FROM_VOLUME_NAME env variable cannot be null. Cannot restore....'
assert FROM_SNAPSHOT_NAME != None and FROM_SNAPSHOT_NAME.strip() != '', 'FROM_SNAPSHOT_NAME env variable cannot be null. Cannot restore ..'




# If automation/scripting tool is inside the same cluster in which Longhorn is installed
longhorn_url = 'http://longhorn-frontend.longhorn-system/v1'
# If forwarding `longhorn-frontend` service to localhost
#longhorn_url = 'http://localhost:8081/v1'

client = longhorn.Client(url=longhorn_url)

# Volume operations
# List all volumes
#volumes = client.list_volume()
#vol = client.by_id_volume(id="pvc-239d1be7-83a2-4bf6-a959-6a33607e458a")
print('Trying to find backup for volume, snapshot ..', FROM_VOLUME_NAME, FROM_SNAPSHOT_NAME)
(bv,b) = common.find_backup(client, FROM_VOLUME_NAME, FROM_SNAPSHOT_NAME)

assert b['state'] == 'Completed', 'Volume state should be Completed. Cannot restore...'
backup_url =  b['url']

print('Backup url to restore from ', backup_url)


print('Creating a new volume from backup url ...', TO_VOLUME_NAME)
client.create_volume(name=TO_VOLUME_NAME,
                         numberOfReplicas=NO_OF_REPLICAS,
                         fromBackup=backup_url)

print('Waiting for volume to be created from backup ')
volume = common.wait_for_volume_detached(client, TO_VOLUME_NAME)

print('Creating a new PV with new volume', TO_PV_NAME)
volume.pvCreate(pvName=TO_PV_NAME)
print('Creating a new PVC with new PV in namespace', TO_PVC_NAME, NAMESPACE)
volume.pvcCreate(namespace=NAMESPACE, pvcName=TO_PVC_NAME)

print('Successfully restored a new volume', volume)
