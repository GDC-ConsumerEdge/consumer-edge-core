export FROM_VOLUME_NAME=test
export FROM_SNAPSHOT_NAME=backup-c-d9c77a51
export TO_PV_NAME=mysql-new-pv
export TO_PVC_NAME=mysql-new-pvc
export TO_VOLUME_NAME=test1
export NAMESPACE=test


#ensure port-forward is running 
# kubectl port-forward services/longhorn-frontend 8080:http -n longhorn-system

#install depedencies 
pip install --no-cache-dir -r requirements.txt


python3 main.py
