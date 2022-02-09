#See most objects in all namespace
kubectl get all --all-namespaces

#See most objects in a namespace
kubectl get all -o wide -n example-local

#See most objects in a namespace with additional detail
kubectl get all -o wide -n example-local

#See all pods in a namespace
kubectl get pod -n example-local

#See meta-data related to a pod
kubectl describe pod/helloworld-web-8495f4c888-zr49f -n example-local

#View folder contents in pod
kubectl exec helloworld-web-8495f4c888-zr49f -n example-local -- ls

#See environment variables in pod
kubectl exec helloworld-web-8495f4c888-zr49f -n example-local -- env

#View Ingress (Routes) in the example-local namespace
kubectl get ing -n example-local
kubectl describe ing helloworld-ingress -n example-local

#View secrets in the example-local namespace
kubectl get secret -n example-local

#Open bash shell to pod from a command prompt
kubectl exec helloworld-web-8495f4c888-zr49f -n example-local -it -- /bin/bash

#Open a command prompt from PowerShell and open a bash shell inside of it.
Start-Process PowerShell -Wait "-NoProfile -ExecutionPolicy Bypass -Command `"kubectl exec helloworld-web-8495f4c888-zr49f -n example-local -it -- /bin/bash`""

#View installed helm charts
helm list -n example-local -a

#Rollback helm chart to first revision
helm rollback helloworld 1 -n example-local

