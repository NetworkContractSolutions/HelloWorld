function Get-ScriptDirectory {
    $directorypath = if ($PSScriptRoot) { $PSScriptRoot } `
        elseif ($psise) { split-path $psise.CurrentFile.FullPath } `
        elseif ($psEditor) { split-path $psEditor.GetEditorContext().CurrentFile.Path }
    return $directorypath
}

Clear-Host
$path = Get-ScriptDirectory
Set-Location $path

Push-Location ..\
docker build -t example/helloworld -f .\Dockerfile . --no-cache
Pop-Location

$dns = 'helloworld.localtest.me'
$temp = "$env:USERPROFILE\temp\HelloWorld"

kubectl create namespace example-local

# Command needed if certificate won't validate
kubectl delete -A ValidatingWebhookConfiguration ingress-nginx-admission

# To YAML then apply: https://stackoverflow.com/questions/45879498/how-can-i-update-a-secret-on-kubernetes-when-it-is-generated-from-a-file
kubectl create secret generic helloworld-tls-secret --from-file=tls.crt="$temp\server.crt" --from-file=tls.key="$temp\server.key" -n example-local --save-config --dry-run=client -o yaml | kubectl apply -f -

Remove-Item *.tgz

#https://helm.sh/docs/intro/quickstart/
helm package ..\charts\helloworld
$helmfile = Get-ChildItem -Filter *.tgz | Select-Object -First 1
helm upgrade helloworld $helmfile.ToString() `
	--namespace example-local --install --wait --timeout 90s `
	--set image.repository=example/helloworld --set image.tag=latest `
    --set ingress.hosts[0].dns=$dns `
    --set ingress.hosts[0].serviceName=helloworld-service `
    --set ingress.tls[0].secretName=helloworld-tls-secret `
    --set ingress.tls[0].hosts[0]=$dns `
	--set secrets[0].name=helloworld-tls-secret
<#
helm list --namespace example-local
helm uninstall helloworld --namespace example-local
kubectl delete namespace example-local
#>
Remove-Item *.tgz

Start-Process "https://$dns"
