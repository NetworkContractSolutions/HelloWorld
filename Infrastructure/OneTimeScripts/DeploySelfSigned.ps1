# https://awkwardferny.medium.com/configuring-certificate-based-mutual-authentication-with-kubernetes-ingress-nginx-20e7e38fdfca
# Currently this only provides a TLS certificate for HTTPS.  
# Working directory assumed to be Infrastructure\OneTimeScripts

Clear-Host

$dns = '*.localtest.me'
$openSSLRoot = 'C:\Program Files\Git\usr\bin'
$userTemp = $env:USERPROFILE + '\temp\HelloWorld'

# Uncomment to not remove and recreate certificates if the ones on disk have not expired.
# $Certs = @(Get-ChildItem Cert:\LocalMachine\Root |
#         Where-Object { $_.Issuer -like '*HelloWorld Authority' -and $_.NotAfter -lt (Get-Date) })
# if (([System.IO.File]::Exists($userTemp + "\server.crt")) -and ([System.IO.File]::Exists($userTemp + "\server.key")) -and ($Certs.length -eq 0)) {
#     exit
# }

Get-ChildItem Cert:\LocalMachine\Root |
Where-Object { $_.Issuer -like '*HelloWorld Authority' } |
Remove-Item

# Assumes Git for windows is installed
Remove-Item "$openSSLRoot\*" -include *.crt, *.pfx, *.csr, *.key, *.ext, *.pem   
Remove-Item "$userTemp\*.*"
((Get-Content -path ".\v3.ext" -Raw) -replace '<DNS>', $dns) | Set-Content -Path "$openSSLRoot\v3.ext"

Set-Location $openSSLRoot
# Generate the CA Key and Certificate
.\openssl req -x509 -sha256 -newkey rsa:4096 -keyout ca.key -out ca.crt -days 356 -nodes -subj '/CN=HelloWorld Authority'

# Generate the Server Key, and Certificate and Sign with the CA Certificate
.\openssl req -new -newkey rsa:4096 -keyout server.key -out server.csr -nodes -subj "/CN=$dns"
.\openssl x509 -req -sha256 -days 365 -in server.csr -CA ca.crt -CAkey ca.key -set_serial (get-date).Ticks -out .\server.crt -extfile .\v3.ext

# # Generate the Client Key, and Certificate and Sign with the CA Certificate
# .\openssl req -new -newkey rsa:4096 -keyout client.key -out client.csr -nodes -subj "/CN=$dns"
# .\openssl x509 -req -sha256 -days 365 -in client.csr -CA ca.crt -CAkey ca.key -set_serial 02 -out client.crt 

# .\openssl pkcs12 -export -out client.pfx -inkey client.key -in client.crt -password pass:Password10
# .\openssl pkcs12 -export -out server.pfx -inkey server.key -in server.crt -password pass:Password10

New-Item -ItemType Directory -Force -Path "$userTemp"  
Copy-Item "$openSSLRoot\*.crt" "$userTemp" -Force
Copy-Item "$openSSLRoot\*.key" "$userTemp" -Force
# Copy-Item "$openSSLRoot\*.pfx" "$userTemp" -Force

Import-Certificate -FilePath "$userTemp\ca.crt" -CertStoreLocation cert:\LocalMachine\Root

# $securePassword = ConvertTo-SecureString -String 'Password10' -AsPlainText -Force
# Import-PfxCertificate -FilePath "$userTemp\client.pfx" -CertStoreLocation cert:\LocalMachine\My -Password $securePassword

# Get-Content "$userTemp\ca.crt", "$userTemp\client.crt" | out-file "$userTemp\combined.crt"
