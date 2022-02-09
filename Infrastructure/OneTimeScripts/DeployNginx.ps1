kubectl create namespace ingress-nginx-local

#https://kubernetes.github.io/ingress-nginx/deploy/ 
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

#Helm and Controller Versions: https://github.com/kubernetes/ingress-nginx/releases
helm upgrade ingress-nginx ingress-nginx/ingress-nginx `
    --namespace ingress-nginx-local --install --version 4.0.16 --wait --timeout 120s `
    --set controller.service.type=LoadBalancer
