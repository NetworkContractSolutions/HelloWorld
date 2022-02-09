# HelloWorld with Kubernetes

Simple HelloWorld application with Kubernetes, Helm and an ingress controller.

##### Dependencies:
1. Kubernetes cluster (this was tested with Docker Desktop's Kubernetes cluster)
1. Helm (https://helm.sh/docs/intro/install/)
1. OpenSSL (comes with Git for Windows)

##### Instructions:
From any PowerShell open and run .\Infrastructure\DeployAll.ps1.

##### Result:
The website https://helloworld.localtest.me should open in your browser once everything has been deployed (refresh the screen a couple of times if you get a default the NGINX page).

##### References:
1. [Kubernetes](https://www.youtube.com/watch?v=X48VuDVv0do)
1. [Helm](https://helm.sh/docs/intro/quickstart/)
1. [Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
1. [OpenSSL with Kubernetes Ingress](https://awkwardferny.medium.com/configuring-certificate-based-mutual-authentication-with-kubernetes-ingress-nginx-20e7e38fdfca)


