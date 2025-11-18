function Test-ConfigurationChange {
    param(
        [object]$Current,
        [array]$Checks
    )
    
    foreach ($check in $Checks) {
        $currentValue = $Current
        
        # Navigate nested properties (e.g., "frontendPort.id")
        foreach ($prop in $check.Field.Split('.')) {
            $currentValue = if ($currentValue) { $currentValue.$prop } else { $null }
        }

        # Apply extractor if specified (e.g., to get last segment of ID)
        if ($check.Extractor) {
            $currentValue = if ($currentValue) { & $check.Extractor $currentValue } else { $null }
        }
        
        # Compare values
        $expectedValue = $check.Expected
        $isMatch = $currentValue -eq $expectedValue
        
        # Handle special cases
        if ($check.AllowNull -and !$currentValue -and !$expectedValue) {
            $isMatch = $true
        }
        
        if (!$isMatch) {
            Write-Host "  $($check.DisplayName) change: $currentValue -> $expectedValue"
            return $true
        }
    }
    
    return $false
}

function Get-ResourceIdName {
    param([string]$ResourceId)
    
    if ($ResourceId) {
        return $ResourceId.Split('/')[-1]
    }
    return $null
}

function Invoke-ConditionalUpdate {
    param(
        [string]$ResourceName,
        [object]$Current,
        [array]$Checks,
        [scriptblock]$UpdateCommand
    )
    
    $needsUpdate = Test-ConfigurationChange -Current $Current -Checks $Checks
    
    if ($needsUpdate) {
        Write-Host "  Updating $ResourceName..."
        & $UpdateCommand
    } else {
        Write-Host "  $ResourceName already configured correctly. Skipping update."
    }
}

# Original Helper Functions
function Get-Json {
    param([string[]] $AzArgs)
    $json = & az @AzArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI failed: az $($AzArgs -join ' ')"
    }
    if ([string]::IsNullOrWhiteSpace($json)) { return @() }
        return ($json | ConvertFrom-Json)
}

function Test-AgwResourceExists {
  param(
    [string] $ResourceGroup,
    [string] $AppGateway,
    [ValidateSet('gateway','address-pool','probe','http-settings','http-listener','rule','url-path-map','frontend-port')] [string] $Type = 'gateway',
    [string] $Name
  )
  
  # If Type is 'gateway', check for the gateway itself
  if ($Type -eq 'gateway') {
    $azParams = @('network','application-gateway','show','-g',$ResourceGroup,'-n',$AppGateway,'--query','id','-o','tsv')
  }
  else {
    $azParams = @('network','application-gateway',$Type,'show','-g',$ResourceGroup,'--gateway-name',$AppGateway,'-n',$Name,'--query','id','-o','tsv')
  }
  
  $id = (& az @azParams 2>$null)
  $exists = ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($id))
  $global:LASTEXITCODE = 0  # Reset to prevent false pipeline failures from "not found" results
  return $exists
}

function Test-DiagnosticSettingsExists {
  param(
    [string] $Name,
    [string] $ResourceId
  )
  
  $azParams = @('monitor','diagnostic-settings','show','--name',$Name,'--resource',$ResourceId,'--query','id','-o','tsv')
  $id = (& az @azParams 2>$null)
  $exists = ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($id))
  $global:LASTEXITCODE = 0  # Reset to prevent false pipeline failures from "not found" results
  return $exists
}

function Set-AppGatewayCore {
    param(
        [object]$SubscriptionConfig,
        [object]$AppGatewayConfig
    )

    $gatewayExists = Test-AgwResourceExists -ResourceGroup $AppGatewayConfig.resourceGroup -AppGateway $AppGatewayConfig.name -Type 'gateway'

    $subnetId = "/subscriptions/$($SubscriptionConfig.subscriptionId)/resourceGroups/$($AppGatewayConfig.vnetRG)/providers/Microsoft.Network/virtualNetworks/$($AppGatewayConfig.vnetName)/subnets/snet-$($AppGatewayConfig.name)"
    $managedIdentityId = "/subscriptions/$($SubscriptionConfig.subscriptionId)/resourceGroups/$($AppGatewayConfig.resourceGroup)/providers/Microsoft.ManagedIdentity/userAssignedIdentities/mi-$($AppGatewayConfig.name)"
    $wafPolicyId = "/subscriptions/$($SubscriptionConfig.subscriptionId)/resourceGroups/$($AppGatewayConfig.wafRG)/providers/Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies/$($AppGatewayConfig.wafName)"
    $publicIPAddress = "pip-$($AppGatewayConfig.name)"
    $privateIPAddress = $AppGatewayConfig.privateIpAddress

    if ($AppGatewayConfig.minCapacity -ne $AppGatewayConfig.maxCapacity) {
        $capacityParams = @(
            "--min-capacity", $($AppGatewayConfig.minCapacity),
            "--max-capacity", $($AppGatewayConfig.maxCapacity)
        )
    } else {
        $capacityParams = @("--capacity", $($AppGatewayConfig.minCapacity))
    }

    if ($gatewayExists) {
        Write-Host "Application Gateway $($AppGatewayConfig.name) already exists. Checking for configuration changes..."

        # Get current configuration
        $currentConfig = az network application-gateway show `
            --name $AppGatewayConfig.name `
            --resource-group $AppGatewayConfig.resourceGroup `
            --query "{minCapacity: sku.capacity, maxCapacity: autoscaleConfiguration.maxCapacity}" `
            --output json | ConvertFrom-Json

        $desiredMinCapacity = $AppGatewayConfig.minCapacity
        $desiredMaxCapacity = if ($AppGatewayConfig.minCapacity -eq $AppGatewayConfig.maxCapacity) { $null } else { $AppGatewayConfig.maxCapacity }

        # Define configuration checks
        $checks = @(
            @{Field='minCapacity'; Expected=$desiredMinCapacity; DisplayName='Min capacity'},
            @{Field='maxCapacity'; Expected=$desiredMaxCapacity; DisplayName='Max capacity'; AllowNull=$true}
        )

        # Check and update if needed
        Invoke-ConditionalUpdate -ResourceName "Application Gateway" -Current $currentConfig -Checks $checks -UpdateCommand {
            az network application-gateway update `
                --name $AppGatewayConfig.name `
                --resource-group $AppGatewayConfig.resourceGroup `
                @capacityParams `
                --tags CreatedBy=IaC IaCTool=CLI DeploymentScope=Custom `
                --output none
        }
    } else {
        Write-Host "Creating Application Gateway $($AppGatewayConfig.name)..."
        az network application-gateway create `
            --name $AppGatewayConfig.name `
            --resource-group $AppGatewayConfig.resourceGroup `
            --location $AppGatewayConfig.location `
            --sku WAF_v2 `
            --subnet $subnetId `
            --public-ip-address $publicIPAddress `
            --private-ip-address $privateIPAddress `
            --identity $managedIdentityId `
            --waf-policy $wafPolicyId `
            --http2 enabled `
            --priority 1 `
            @capacityParams `
            --tags CreatedBy=IaC IaCTool=CLI DeploymentScope=Custom `
            --output none
    }
}

# This function cleans up default resources from existing Application Gateways
# that were created before the cleanup was added to Set-AppGatewayCore
function Remove-AppGatewayDefaultResources {
    param(
        [string]$GatewayName,
        [string]$ResourceGroup
    )

    Write-Host "Checking for default resources to clean up..."

    # Check if default listener exists (indicates cleanup is needed)
    if (Test-AgwResourceExists -ResourceGroup $ResourceGroup -AppGateway $GatewayName -Type 'http-listener' -Name 'appGatewayHttpListener') {
        # Remove default rule (must be done before removing listener)
        if (Test-AgwResourceExists -ResourceGroup $ResourceGroup -AppGateway $GatewayName -Type 'rule' -Name 'rule1') {
            Write-Host "    Removing default rule 'rule1'..."
            az network application-gateway rule delete `
                --gateway-name $GatewayName `
                --resource-group $ResourceGroup `
                --name 'rule1' `
                --output none
        }

        # Remove default HTTP listener
        Write-Host "    Removing default listener 'appGatewayHttpListener'..."
        az network application-gateway http-listener delete `
            --gateway-name $GatewayName `
            --resource-group $ResourceGroup `
            --name 'appGatewayHttpListener' `
            --output none

        # Remove default HTTP settings
        if (Test-AgwResourceExists -ResourceGroup $ResourceGroup -AppGateway $GatewayName -Type 'http-settings' -Name 'appGatewayBackendHttpSettings') {
            Write-Host "    Removing default HTTP settings 'appGatewayBackendHttpSettings'..."
            az network application-gateway http-settings delete `
                --gateway-name $GatewayName `
                --resource-group $ResourceGroup `
                --name 'appGatewayBackendHttpSettings' `
                --output none
        }

        # Remove default backend pool
        if (Test-AgwResourceExists -ResourceGroup $ResourceGroup -AppGateway $GatewayName -Type 'address-pool' -Name 'appGatewayBackendPool') {
            Write-Host "    Removing default backend pool 'appGatewayBackendPool'..."
            az network application-gateway address-pool delete `
                --gateway-name $GatewayName `
                --resource-group $ResourceGroup `
                --name 'appGatewayBackendPool' `
                --output none
        }

        # Remove default frontend port (port 80)
        if (Test-AgwResourceExists -ResourceGroup $ResourceGroup -AppGateway $GatewayName -Type 'frontend-port' -Name 'appGatewayFrontendPort') {
            Write-Host "    Removing default frontend port 'appGatewayFrontendPort'..."
            az network application-gateway frontend-port delete `
                --gateway-name $GatewayName `
                --resource-group $ResourceGroup `
                --name 'appGatewayFrontendPort'
        }
    }

    Write-Host "  Default resources cleaned up successfully."
}

function Remove-FrontendPort {
    param(
        [string]$GatewayName,
        [string]$ResourceGroup,
        [string]$PortName,
        [string]$NewPortName
    )

    if (Test-AgwResourceExists -ResourceGroup $ResourceGroup -AppGateway $GatewayName -Type 'frontend-port' -Name $PortName) {
        Write-Host "  Checking for listeners using frontend port '$PortName'..."

        # Get all listeners using this port
        $listeners = az network application-gateway http-listener list `
            --gateway-name $GatewayName `
            --resource-group $ResourceGroup `
            --query "[?ends_with(frontendPort.id, '/$PortName')].name" `
            --output json | ConvertFrom-Json

        if ($listeners -and $listeners.Count -gt 0) {
            # Reassign listeners to new port
            Write-Host "  Reassigning $($listeners.Count) listener(s) from '$PortName' to '$NewPortName'..."
            foreach ($listenerName in $listeners) {
                Write-Host "    Updating listener '$listenerName'..."
                az network application-gateway http-listener update `
                    --gateway-name $GatewayName `
                    --resource-group $ResourceGroup `
                    --name $listenerName `
                    --frontend-port $NewPortName `
                    --output none
            }
            Write-Host "  Listeners reassigned successfully."
        }

        Write-Host "  Removing frontend port '$PortName'..."
        az network application-gateway frontend-port delete `
            --gateway-name $GatewayName `
            --resource-group $ResourceGroup `
            --name $PortName `
            --output none

        Write-Host "  Frontend port '$PortName' removed successfully."
    } else {
        Write-Host "  Frontend port '$PortName' does not exist. Skipping removal."
    }
}

function Set-AppGatewaySslPolicy {
    param(
        [string]$GatewayName,
        [string]$ResourceGroup,
        [string]$PolicyName = "AppGwSslPolicy20220101"
    )
    
    $currentPolicy = az network application-gateway ssl-policy show `
        --resource-group $ResourceGroup `
        --gateway-name $GatewayName `
        --query "policyName" `
        --output tsv 2>$null
    
    if ($currentPolicy -ne $PolicyName) {
        az network application-gateway ssl-policy set `
            --resource-group $ResourceGroup `
            --gateway-name $GatewayName `
            --policy-type Predefined `
            --name $PolicyName
    }
}

function Set-AppGatewayFrontendPort {
    param(
        [string]$GatewayName,
        [string]$ResourceGroup,
        [string]$PortName,
        [int]$Port
    )
    
    $exists = Test-AgwResourceExists -ResourceGroup $ResourceGroup -AppGateway $GatewayName -Type 'frontend-port' -Name $PortName
    if (-not $exists) {
        az network application-gateway frontend-port create `
            --name $PortName `
            --resource-group $ResourceGroup `
            --gateway-name $GatewayName `
            --port $Port `
            --only-show-errors `
            --output none
    } else {
        # Check if port needs updating
        $currentPort = az network application-gateway frontend-port show `
            --name $PortName `
            --resource-group $ResourceGroup `
            --gateway-name $GatewayName `
            --query "port" `
            --output tsv
        
        if ($currentPort -ne $Port) {
            Write-Host "  Frontend port change detected for $PortName : $currentPort -> $Port"
            az network application-gateway frontend-port update `
                --name $PortName `
                --resource-group $ResourceGroup `
                --gateway-name $GatewayName `
                --port $Port `
                --only-show-errors `
                --output none
        } else {
            Write-Host "  Frontend port $PortName already configured with port $Port. Skipping update."
        }
    }
}

function Set-AppGatewaySslCertificate {
    param(
        [string]$GatewayName,
        [string]$ResourceGroup,
        [string]$CertName,
        [string]$KeyVaultSecretId
    )
    
    $currentCert = az network application-gateway ssl-cert show `
        --name $CertName `
        --resource-group $ResourceGroup `
        --gateway-name $GatewayName `
        --query "keyVaultSecretId" `
        --output tsv 2>$null
    
    if (-not $currentCert) {
        Write-Host "  Creating SSL certificate $CertName..."
        az network application-gateway ssl-cert create `
            --name $CertName `
            --resource-group $ResourceGroup `
            --gateway-name $GatewayName `
            --key-vault-secret-id $KeyVaultSecretId `
            --output none
    } else {
        if ($currentCert -ne $KeyVaultSecretId) {
            Write-Host "  SSL certificate change detected for $CertName"
            az network application-gateway ssl-cert update `
                --name $CertName `
                --resource-group $ResourceGroup `
                --gateway-name $GatewayName `
                --key-vault-secret-id $KeyVaultSecretId `
                --output none
        } else {
            Write-Host "  SSL certificate $CertName already configured correctly. Skipping update."
        }
    }
}

function Set-AppGatewayAddressPool {
    param(
        [string]$GatewayName,
        [string]$ResourceGroup,
        [string]$PoolName,
        [string]$ServerFqdn
    )
    
    $exists = Test-AgwResourceExists -ResourceGroup $ResourceGroup -AppGateway $GatewayName -Type 'address-pool' -Name $PoolName
    if (-not $exists) {
        Write-Host "  Creating backend pool $PoolName..."
        az network application-gateway address-pool create `
            --gateway-name $GatewayName `
            --resource-group $ResourceGroup `
            --name $PoolName `
            --servers $ServerFqdn `
            --output none
    } else {
        # Check if backend pool needs updating
        $currentServers = az network application-gateway address-pool show `
            --gateway-name $GatewayName `
            --resource-group $ResourceGroup `
            --name $PoolName `
            --query "backendAddresses[0].fqdn" `
            --output tsv
        
        if ($currentServers -ne $ServerFqdn) {
            Write-Host "  Backend pool change detected for $PoolName : $currentServers -> $ServerFqdn"
            az network application-gateway address-pool update `
                --gateway-name $GatewayName `
                --resource-group $ResourceGroup `
                --name $PoolName `
                --servers $ServerFqdn `
                --output none
        } else {
            Write-Host "  Backend pool $PoolName already configured correctly. Skipping update."
        }
    }
}

function Set-AppGatewayProbe {
    param(
        [string]$GatewayName,
        [string]$ResourceGroup,
        [string]$ProbeName,
        [string]$HostFqdn,
        [hashtable]$ProbeConfig = @{}
    )
    
    # Default health probe settings (can be overridden via ProbeConfig)
    $path = if ($ProbeConfig.path) { $ProbeConfig.path } else { "/" }
    $interval = if ($ProbeConfig.interval) { $ProbeConfig.interval } else { 30 }
    $timeout = if ($ProbeConfig.timeout) { $ProbeConfig.timeout } else { 30 }
    $threshold = if ($ProbeConfig.threshold) { $ProbeConfig.threshold } else { 3 }
    $statusCodes = if ($ProbeConfig.matchStatusCodes) { $ProbeConfig.matchStatusCodes } else { "200-399" }
    
    $exists = Test-AgwResourceExists -ResourceGroup $ResourceGroup -AppGateway $GatewayName -Type 'probe' -Name $ProbeName
    if (-not $exists) {
        Write-Host "  Creating health probe $ProbeName..."
        az network application-gateway probe create `
            --gateway-name $GatewayName `
            --resource-group $ResourceGroup `
            --name $ProbeName `
            --protocol Https `
            --path $path `
            --host $HostFqdn `
            --interval $interval `
            --timeout $timeout `
            --threshold $threshold `
            --match-status-codes $statusCodes `
            --output none
    } else {
        # Get current configuration
        $currentProbe = az network application-gateway probe show `
            --gateway-name $GatewayName `
            --resource-group $ResourceGroup `
            --name $ProbeName `
            --query "{protocol: protocol, path: path, host: host, interval: interval, timeout: timeout, threshold: unhealthyThreshold}" `
            --output json 2>$null | ConvertFrom-Json
        
        # Define configuration checks
        $checks = @(
            @{Field='protocol'; Expected='Https'; DisplayName='Probe protocol'},
            @{Field='path'; Expected=$path; DisplayName='Probe path'},
            @{Field='host'; Expected=$HostFqdn; DisplayName='Probe host'},
            @{Field='interval'; Expected=$interval; DisplayName='Probe interval'},
            @{Field='timeout'; Expected=$timeout; DisplayName='Probe timeout'},
            @{Field='threshold'; Expected=$threshold; DisplayName='Probe threshold'}
        )
        
        # Check and update if needed
        Invoke-ConditionalUpdate -ResourceName "health probe $ProbeName" -Current $currentProbe -Checks $checks -UpdateCommand {
            az network application-gateway probe update `
                --gateway-name $GatewayName `
                --resource-group $ResourceGroup `
                --name $ProbeName `
                --protocol Https `
                --path $path `
                --host $HostFqdn `
                --interval $interval `
                --timeout $timeout `
                --threshold $threshold `
                --match-status-codes $statusCodes `
                --output none
        }
    }
}

function Set-AppGatewayHttpSettings {
    param(
        [string]$GatewayName,
        [string]$ResourceGroup,
        [string]$SettingsName,
        [string]$ProbeName,
        [hashtable]$HttpSettingsConfig = @{}
    )
    
    # Default HTTP settings (can be overridden via HttpSettingsConfig)
    $cookieAffinity = if ($HttpSettingsConfig.cookieBasedAffinity) { $HttpSettingsConfig.cookieBasedAffinity } else { "Disabled" }
    $drainTimeout = if ($HttpSettingsConfig.drainTimeout) { $HttpSettingsConfig.drainTimeout } else { 30 }
    
    # Connection draining is automatically enabled when cookie affinity is enabled
    $drainParams = @()
    if ($cookieAffinity -eq 'Enabled') {
        $drainParams = @('--connection-draining', 'true', '--drain-timeout', $drainTimeout)
    }
    
    $exists = Test-AgwResourceExists -ResourceGroup $ResourceGroup -AppGateway $GatewayName -Type 'http-settings' -Name $SettingsName
    if (-not $exists) {
        Write-Host "  Creating HTTP settings $SettingsName..."
        az network application-gateway http-settings create `
            --gateway-name $GatewayName `
            --resource-group $ResourceGroup `
            --name $SettingsName `
            --port 443 `
            --protocol Https `
            --cookie-based-affinity $cookieAffinity `
            --host-name-from-backend-pool true `
            --probe $ProbeName `
            @drainParams `
            --output none
    } else {
        # Get current configuration
        $currentSettings = az network application-gateway http-settings show `
            --gateway-name $GatewayName `
            --resource-group $ResourceGroup `
            --name $SettingsName `
            --query "{port: port, protocol: protocol, cookieAffinity: cookieBasedAffinity, hostNameFromBackendPool: pickHostNameFromBackendAddress, drainTimeout: connectionDraining.drainTimeoutInSec}" `
            --output json 2>$null | ConvertFrom-Json
        
        # Define configuration checks
        $checks = @(
            @{Field='port'; Expected=443; DisplayName='Port'},
            @{Field='protocol'; Expected='Https'; DisplayName='Protocol'},
            @{Field='cookieAffinity'; Expected=$cookieAffinity; DisplayName='Cookie affinity'},
            @{Field='hostNameFromBackendPool'; Expected=$true; DisplayName='Host name from backend pool'}
        )
        
        # Add drain timeout check only if cookie affinity is enabled
        if ($cookieAffinity -eq 'Enabled') {
            $checks += @{Field='drainTimeout'; Expected=$drainTimeout; DisplayName='Drain timeout'}
        }
        
        # Check and update if needed
        Invoke-ConditionalUpdate -ResourceName "HTTP settings $SettingsName" -Current $currentSettings -Checks $checks -UpdateCommand {
            az network application-gateway http-settings update `
                --gateway-name $GatewayName `
                --resource-group $ResourceGroup `
                --name $SettingsName `
                --port 443 `
                --protocol Https `
                --cookie-based-affinity $cookieAffinity `
                --host-name-from-backend-pool true `
                --probe $ProbeName `
                @drainParams `
                --output none
        }
    }
}

function Set-AppGatewayHttpListener {
    param(
        [string]$GatewayName,
        [string]$ResourceGroup,
        [string]$ListenerName,
        [string]$FrontendIpName,
        [string]$SslCertName = $null,
        [string]$WafPolicyId,
        [string]$HostName,
        [switch]$UseHttps,
        [string]$FrontendPortName
    )

    # Validate SSL certificate requirement
    if ($UseHttps -and [string]::IsNullOrWhiteSpace($SslCertName)) {
        throw "SSL certificate name is required for HTTPS listeners"
    }

    $exists = Test-AgwResourceExists -ResourceGroup $ResourceGroup -AppGateway $GatewayName -Type 'http-listener' -Name $ListenerName
    if (-not $exists) {
        Write-Host "  Creating HTTP listener $ListenerName..."

        $params = @()
        if ($UseHttps) {
            $params += '--ssl-cert', $SslCertName
        }
        if ($WafPolicyId) {
            $params += '--waf-policy', $WafPolicyId
        }

        az network application-gateway http-listener create `
            --name $ListenerName `
            --gateway-name $GatewayName `
            --resource-group $ResourceGroup `
            --frontend-port $FrontendPortName `
            --frontend-ip $FrontendIpName `
            --host-name $HostName `
            @params `
            --output none
    } else {
        # Get current configuration
        $currentListener = az network application-gateway http-listener show `
            --gateway-name $GatewayName `
            --resource-group $ResourceGroup `
            --name $ListenerName `
            --query "{hostName: hostName, frontendPort: frontendPort.id, frontendIp: frontendIPConfiguration.id, sslCert: sslCertificate.id}" `
            --output json 2>$null | ConvertFrom-Json

        # Define configuration checks with ID extraction
        $checks = @(
            @{Field='frontendPort'; Expected=$FrontendPortName; DisplayName='Frontend port'; Extractor={param($id) Get-ResourceIdName $id}},
            @{Field='frontendIp'; Expected=$FrontendIpName; DisplayName='Frontend IP'; Extractor={param($id) Get-ResourceIdName $id}},
            @{Field='hostName'; Expected=$HostName; DisplayName='Listener hostname'}
        )

        if ($UseHttps) {
            $checks += @{Field='sslCert'; Expected=$SslCertName; DisplayName='SSL certificate'; Extractor={param($id) Get-ResourceIdName $id}}
        }

        # Check and update if needed
        Invoke-ConditionalUpdate -ResourceName "HTTP listener $ListenerName" -Current $currentListener -Checks $checks -UpdateCommand {
            $params = @()
            if ($UseHttps) {
                $params += '--ssl-cert', $SslCertName
            }
            if ($WafPolicyId) {
                $params += '--waf-policy', $WafPolicyId
            }

            az network application-gateway http-listener update `
                --name $ListenerName `
                --gateway-name $GatewayName `
                --resource-group $ResourceGroup `
                --frontend-port $FrontendPortName `
                --frontend-ip $FrontendIpName `
                --host-name $HostName `
                @params `
                --output none
        }
    }
}

function Set-AppGatewayRedirectConfig {
    param(
        [string]$GatewayName,
        [string]$ResourceGroup,
        [string]$ConfigName,
        [string]$TargetListenerName,
        [string]$RedirectType = "Permanent",
        [bool]$IncludePath = $true,
        [bool]$IncludeQueryString = $true
    )

    $exists = az network application-gateway redirect-config show `
        --gateway-name $GatewayName `
        --resource-group $ResourceGroup `
        --name $ConfigName `
        --query "id" `
        --output tsv 2>$null

    if (-not $exists) {
        Write-Host "  Creating redirect configuration $ConfigName..."
        az network application-gateway redirect-config create `
            --gateway-name $GatewayName `
            --resource-group $ResourceGroup `
            --name $ConfigName `
            --type $RedirectType `
            --target-listener $TargetListenerName `
            --include-path $IncludePath `
            --include-query-string $IncludeQueryString `
            --output none
    } else {
        Write-Host "  Redirect configuration $ConfigName already exists. Skipping update."
    }
}

function Set-AppGatewayRule {
    param(
        [string]$GatewayName,
        [string]$ResourceGroup,
        [string]$RuleName,
        [string]$ListenerName,
        [string]$AddressPoolName,
        [string]$HttpSettingsName,
        [int]$Priority,
        [string]$RedirectConfigName = $null,
        [string]$RuleType = "Basic"
    )
    
    $exists = Test-AgwResourceExists -ResourceGroup $ResourceGroup -AppGateway $GatewayName -Type 'rule' -Name $RuleName
    if (-not $exists) {
        Write-Host "  Creating routing rule $RuleName with priority $Priority..."

        $params = @()
        if ($RedirectConfigName) {
            $params = @('--redirect-config', $RedirectConfigName)
        } else {
            $params = @('--address-pool', $AddressPoolName, '--http-settings', $HttpSettingsName)
        }

        az network application-gateway rule create `
            --gateway-name $GatewayName `
            --resource-group $ResourceGroup `
            --name $RuleName `
            --http-listener $ListenerName `
            --rule-type $RuleType `
            --priority $Priority `
            @params `
            --output none
    } else {
        # Get current configuration
        $currentRule = az network application-gateway rule show `
            --gateway-name $GatewayName `
            --resource-group $ResourceGroup `
            --name $RuleName `
            --query "{ruleType: ruleType, listener: httpListener.id, pool: backendAddressPool.id, settings: backendHttpSettings.id, redirectConfig: redirectConfiguration.id}" `
            --output json 2>$null | ConvertFrom-Json

        # Define configuration checks with ID extraction
        $checks = @(
            @{Field='ruleType'; Expected=$RuleType; DisplayName='Rule type'},
            @{Field='listener'; Expected=$ListenerName; DisplayName='Listener'; Extractor={param($id) Get-ResourceIdName $id}}
        )

        if ($RedirectConfigName) {
            $checks += @{Field='redirectConfig'; Expected=$RedirectConfigName; DisplayName='Redirect config'; Extractor={param($id) Get-ResourceIdName $id}}
        } else {
            $checks += @{Field='pool'; Expected=$AddressPoolName; DisplayName='Backend pool'; Extractor={param($id) Get-ResourceIdName $id}}
            $checks += @{Field='settings'; Expected=$HttpSettingsName; DisplayName='HTTP settings'; Extractor={param($id) Get-ResourceIdName $id}}
        }

        # Check and update if needed
        Invoke-ConditionalUpdate -ResourceName "routing rule $RuleName" -Current $currentRule -Checks $checks -UpdateCommand {
            $params = @()
            if ($RedirectConfigName) {
                $params = @('--redirect-config', $RedirectConfigName)
            } else {
                $params = @('--address-pool', $AddressPoolName, '--http-settings', $HttpSettingsName)
            }

            az network application-gateway rule update `
                --gateway-name $GatewayName `
                --resource-group $ResourceGroup `
                --name $RuleName `
                --http-listener $ListenerName `
                --rule-type $RuleType `
                @params `
                --output none
            # --priority $Priority  # Don't update Priority after creation
        }
    }
}

function Set-PrivateDnsRecord {
    param(
        [string]$DnsZoneName,
        [string]$DnsZoneResourceGroup,
        [string]$DnsZoneSubscriptionId,
        [string]$RecordName,
        [string]$IpAddress
    )
    
    $existingRecord = az network private-dns record-set a show `
        --subscription $DnsZoneSubscriptionId `
        --zone-name $DnsZoneName `
        --resource-group $DnsZoneResourceGroup `
        --name $RecordName `
        --query "id" `
        --output tsv 2>$null
    
    if ($existingRecord) {
        az network private-dns record-set a update `
            --subscription $DnsZoneSubscriptionId `
            --zone-name $DnsZoneName `
            --resource-group $DnsZoneResourceGroup `
            --name $RecordName `
            --set "aRecords[0].ipv4Address=$IpAddress" `
            --output none
    } else {
        az network private-dns record-set a create `
            --subscription $DnsZoneSubscriptionId `
            --zone-name $DnsZoneName `
            --resource-group $DnsZoneResourceGroup `
            --name $RecordName `
            --ttl 3600 `
            --output none
        
        az network private-dns record-set a add-record `
            --subscription $DnsZoneSubscriptionId `
            --zone-name $DnsZoneName `
            --resource-group $DnsZoneResourceGroup `
            --record-set-name $RecordName `
            --ipv4-address $IpAddress `
            --output none
    }
}

function Set-AppGatewayDiagnostics {
    param(
        [string]$GatewayName,
        [string]$ResourceGroup,
        [string]$WorkspaceName,
        [string]$WorkspaceResourceGroup,
        [string]$SubscriptionId
    )
    
    Write-Host "Configuring diagnostics for Application Gateway $GatewayName..."
    
    # Get workspace resource ID
    $workspaceId = "/subscriptions/$SubscriptionId/resourceGroups/$WorkspaceResourceGroup/providers/Microsoft.OperationalInsights/workspaces/$WorkspaceName"
    $resourceId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Network/applicationGateways/$GatewayName"
    $diagnosticName = "dx-${GatewayName}"
    
    # Check if diagnostic settings already exist
    $diagnosticExists = Test-DiagnosticSettingsExists -Name $diagnosticName -ResourceId $resourceId
    
    if ($diagnosticExists) {
        Write-Host "  Updating existing diagnostic settings..."
        # Update existing diagnostic settings
        az monitor diagnostic-settings update `
            --name $diagnosticName `
            --resource $resourceId `
            --workspace $workspaceId `
            --logs '[{"category": "ApplicationGatewayAccessLog", "enabled": true}, {"category": "ApplicationGatewayPerformanceLog", "enabled": true}, {"category": "ApplicationGatewayFirewallLog", "enabled": true}]' `
            --metrics '[{"category": "AllMetrics", "enabled": false}]' `
            --output none
    } else {
        Write-Host "  Creating new diagnostic settings..."
        # Create new diagnostic settings
        az monitor diagnostic-settings create `
            --name $diagnosticName `
            --resource $resourceId `
            --workspace $workspaceId `
            --logs '[{"category": "ApplicationGatewayAccessLog", "enabled": true}, {"category": "ApplicationGatewayPerformanceLog", "enabled": true}, {"category": "ApplicationGatewayFirewallLog", "enabled": true}]' `
            --metrics '[{"category": "AllMetrics", "enabled": false}]' `
            --output none
    }
    
    Write-Host "Diagnostics configured successfully"
}

function Ensure-CAEApplicationGateways {
    param(
        [object]$SubscriptionConfig,
        [object]$AppGatewayConfig
    )

    Set-AppGatewayCore -SubscriptionConfig $SubscriptionConfig -AppGatewayConfig $AppGatewayConfig

    # Set SSL/TLS policy (defaults to AppGwSslPolicy20220101 which requires TLS 1.2+)
    $sslPolicy = if ($AppGatewayConfig.sslPolicy) { $AppGatewayConfig.sslPolicy } else { "AppGwSslPolicy20220101" }
    Set-AppGatewaySslPolicy -GatewayName $AppGatewayConfig.name -ResourceGroup $AppGatewayConfig.resourceGroup -PolicyName $sslPolicy

    # Create or update frontend ports for HTTPS and HTTP
    Set-AppGatewayFrontendPort -GatewayName $AppGatewayConfig.name -ResourceGroup $AppGatewayConfig.resourceGroup -PortName 'fp-443' -Port 443

    # Handle default port 80 conflict (only needed on first run when default port exists)
    if (Test-AgwResourceExists -ResourceGroup $AppGatewayConfig.resourceGroup -AppGateway $AppGatewayConfig.name -Type 'frontend-port' -Name 'appGatewayFrontendPort') {
        # Azure CLI doesn't support renaming ports, so we need this workaround
        Set-AppGatewayFrontendPort -GatewayName $AppGatewayConfig.name -ResourceGroup $AppGatewayConfig.resourceGroup -PortName 'fp-81' -Port 81
        Remove-FrontendPort -GatewayName $AppGatewayConfig.name -ResourceGroup $AppGatewayConfig.resourceGroup -PortName 'appGatewayFrontendPort' -NewPortName 'fp-81'
        Set-AppGatewayFrontendPort -GatewayName $AppGatewayConfig.name -ResourceGroup $AppGatewayConfig.resourceGroup -PortName 'fp-80' -Port 80
        Remove-FrontendPort -GatewayName $AppGatewayConfig.name -ResourceGroup $AppGatewayConfig.resourceGroup -PortName 'fp-81' -NewPortName 'fp-80'
    } else {
        # Normal case - just create port 80
        Set-AppGatewayFrontendPort -GatewayName $AppGatewayConfig.name -ResourceGroup $AppGatewayConfig.resourceGroup -PortName 'fp-80' -Port 80
    }

    foreach ($cert in $AppGatewayConfig.certificates) {
        # Create or update SSL certificate reference to Key Vault
        Set-AppGatewaySslCertificate -GatewayName $AppGatewayConfig.name -ResourceGroup $AppGatewayConfig.resourceGroup -CertName $cert.certSecretName -KeyVaultSecretId $cert.certSecretUrl
    }

    # Configure diagnostics
    if ($AppGatewayConfig.logAnalyticsWorkspace -and $AppGatewayConfig.logAnalyticsRG) {
        Set-AppGatewayDiagnostics `
            -GatewayName $AppGatewayConfig.name `
            -ResourceGroup $AppGatewayConfig.resourceGroup `
            -WorkspaceName $AppGatewayConfig.logAnalyticsWorkspace `
            -WorkspaceResourceGroup $AppGatewayConfig.logAnalyticsRG `
            -SubscriptionId $SubscriptionConfig.subscriptionId
    }

    Write-Host "Application Gateway '$($AppGatewayConfig.name)' created successfully in resource group '$($AppGatewayConfig.resourceGroup)'."
}

function Deploy-CAEApplicationGateways {
    param(
        [object]$SubscriptionConfig,
        [array]$ApplicationGateways,
        [array]$CaeConfigs
    )
    $ApplicationGateways = $ApplicationGateways ?? @()
    $CaeConfigs = $CaeConfigs ?? @()

    # Get unique app gateways referenced by CAE configs
    $referencedGateways = $CaeConfigs | ForEach-Object {
        @{ name = $_.appGateway.name; resourceGroup = $_.appGateway.resourceGroup }
    } | Sort-Object name, resourceGroup -Unique
    
    # Filter application gateways to only those referenced by CAE configs
    $filteredGateways = $ApplicationGateways | Where-Object {
        $agw = $_
        $referencedGateways | Where-Object { $_.name -eq $agw.name -and $_.resourceGroup -eq $agw.resourceGroup }
    }

    foreach ($appGatewayConfig in $filteredGateways) {
        Write-Host "-----------------------------------------------------"
        Write-Host "Deploy AppGateway $($appGatewayConfig.name)"

        Ensure-CAEApplicationGateways `
            -subscriptionConfig $SubscriptionConfig `
            -appGatewayConfig $appGatewayConfig
    }
}

function Get-RulePriority {
    param(
        [string]$GatewayName,
        [string]$ResourceGroup,
        [string]$RuleName
    )

    $json = az network application-gateway rule show --gateway-name $GatewayName --resource-group $ResourceGroup --name $RuleName 2>$null
    if ($json) {
        $rule = $json | ConvertFrom-Json
        if ($rule -and $rule.priority) { return $rule.priority; }
    }

    $max = az network application-gateway rule list `
        --gateway-name $GatewayName `
        --resource-group $ResourceGroup `
        --query "[?priority!=null].priority | max(@)" `
        -o tsv

    if (-not $max) { return 10; } else { return [math]::Floor($max / 10.0) * 10 + 10; }
}

<#
$subscriptionConfig = (Get-Parameters -filePath './Subscriptions/Ncontracts_DevTest/Subscription.json').subscriptionConfig.value
$environmentConfig = (Get-Parameters -filePath 'C:\dev\Ncontracts.Infrastructure\Environment\Dev\Parameters\Feature07.json').environmentConfig.value
$caeConfig = $environmentConfig.caeConfigs[0]
Ensure-ContainerAppIntegration -SubscriptionConfig $subscriptionConfig -EnvironmentConfig $environmentConfig -CaeConfig $caeConfig
#>
function Ensure-ContainerAppIntegration {
    param(
        [object]$SubscriptionConfig,
        [object]$EnvironmentConfig,
        [object]$CaeConfig,
        [string]$ContainerAppFilter = $null,
        [hashtable]$ProbeConfig = $null,
        [hashtable]$HttpSettingsConfig = $null,
        [bool]$BrowserFriendlyRouting = $false,
        [bool]$InternalOnly = $false
    )
    
    Write-Host "Starting Container App Integration for CAE: $($CaeConfig.name)"
    
    # App Gateway Config Properties
    $agwName = $caeConfig.appGateway.name
    $agwRG = $caeConfig.appGateway.resourceGroup
    Write-Host "Target Application Gateway: $agwName in resource group $agwRG"

    Write-Host "Verifying Application Gateway exists..."
    if (-not(Test-AgwResourceExists -ResourceGroup $agwRG -AppGateway $agwName -Type 'gateway')) {
        Write-Host "Application Gateway $agwName does not exist in resource group $agwRG. Skipping."
        return
    }
    Write-Host "Application Gateway found successfully"

    Write-Host "Loading Application Gateway configuration..."
    $appGatewayConfig = $EnvironmentConfig.applicationGateways | Where-Object { $_.name -eq $agwName -and $_.resourceGroup -eq $agwRG }
    $agwWafRG = $appGatewayConfig.wafRG
    $agwWafName = $appGatewayConfig.wafName
    $agwCertSecretName = $appGatewayConfig.certificates[0].certSecretName

    # CAE Config Properties
    $caeRG = $caeConfig.resourceGroup
    $caeName = $caeConfig.name
    $privateDnsZoneName = $caeConfig.privateDnsZone.name
    $privateDnsZoneRG = $caeConfig.privateDnsZone.resourceGroup
    $privateDnsZoneSubscriptionId = $caeConfig.privateDnsZone.subscriptionId
    
    # Get Application Gateway private IP for DNS records
    Write-Host "Retrieving Application Gateway private IP address..."
    $agwPrivateIp = az network application-gateway show `
        --name $agwName `
        --resource-group $agwRG `
        --query "frontendIPConfigurations[?privateIPAddress!=null].privateIPAddress | [0]" `
        --output tsv
    Write-Host "Application Gateway private IP: $agwPrivateIp"

    Write-Host "Retrieving Container Apps from environment $caeName..."
    $apps = Get-Json @('containerapp','list','--resource-group',$caeRG,'--environment',$caeName,'-o','json')
    
    # Apply filter (always provided, .* matches all)
    if ($ContainerAppFilter) {
        Write-Host "Applying filter pattern: $ContainerAppFilter"
        $apps = $apps | Where-Object { $_.name -match $ContainerAppFilter }
        if (-not $apps) {
            Write-Warning "No Container Apps matching filter '$ContainerAppFilter' found in environment $caeName"
            return
        }
    }
    
    # Filter out apps without ingress enabled
    $apps = $apps | Where-Object { $_.properties.configuration.ingress -and $_.properties.configuration.ingress.external }
    Write-Host "Found $($apps.Count) Container Apps with external ingress enabled"

    $environmentId = $EnvironmentConfig.environmentId
    if ($environmentId -eq 'prd') { $environmentId = '' } else { $environmentId = "-$environmentId" }
    foreach ($app in $apps) {
        $appName = "$($app.name)$environmentId"
        $dnsName = "$($app.name)$environmentId"
        $appFqdn = $app.properties.configuration.ingress.fqdn
        $listenerFqdn = "$dnsName.$privateDnsZoneName"
        
        Write-Host "Processing Container App: $($app.name) -> $appName"
        Write-Host "  App FQDN: $appFqdn"
        Write-Host "  Listener FQDN: $listenerFqdn"

        Write-Host "  Creating/updating address pool: ap-$appName"
        Set-AppGatewayAddressPool -GatewayName $agwName -ResourceGroup $agwRG -PoolName "ap-$appName" -ServerFqdn $appFqdn

        Write-Host "  Creating/updating health probe: probe-$appName"

        # Use provided ProbeConfig for all apps being processed
        $appProbeConfig = if ($ProbeConfig) { $ProbeConfig } else { @{} }
        if ($ProbeConfig) {
            Write-Host "    Using custom probe configuration from parameter"
        }

        Set-AppGatewayProbe -GatewayName $agwName -ResourceGroup $agwRG -ProbeName "probe-$appName" -HostFqdn $appFqdn -ProbeConfig $appProbeConfig

        Write-Host "  Creating/updating HTTP settings: hs-$appName"
        Set-AppGatewayHttpSettings -GatewayName $agwName -ResourceGroup $agwRG -SettingsName "hs-$appName" -ProbeName "probe-$appName" -HttpSettingsConfig $HttpSettingsConfig

        Write-Host "  Creating/updating HTTP listeners for $appName"
        $wafPolicyId = "/subscriptions/$($SubscriptionConfig.subscriptionId)/resourceGroups/$agwWafRG/providers/Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies/$agwWafName"

        # HTTPS listeners
        Write-Host "  Private HTTPS listener: list-private-$appName"
        Set-AppGatewayHttpListener -GatewayName $agwName -ResourceGroup $agwRG -ListenerName "list-private-$appName" -FrontendIpName "appGatewayPrivateFrontendIP" -SslCertName $agwCertSecretName -WafPolicyId $wafPolicyId -HostName $listenerFqdn -UseHttps -FrontendPortName "fp-443"

        if (-not $InternalOnly) {
            Write-Host "  Public HTTPS listener: list-public-$appName"
            Set-AppGatewayHttpListener -GatewayName $agwName -ResourceGroup $agwRG -ListenerName "list-public-$appName" -FrontendIpName "appGatewayFrontendIP" -SslCertName $agwCertSecretName -WafPolicyId $wafPolicyId -HostName $listenerFqdn -UseHttps -FrontendPortName "fp-443"
        }

        if ($BrowserFriendlyRouting) {
            # HTTP listeners for redirect
            Write-Host "  Private HTTP listener: list-private-http-$appName"
            Set-AppGatewayHttpListener -GatewayName $agwName -ResourceGroup $agwRG -ListenerName "list-private-http-$appName" -FrontendIpName "appGatewayPrivateFrontendIP" -HostName $listenerFqdn -FrontendPortName "fp-80"

            if (-not $InternalOnly) {
                Write-Host "  Public HTTP listener: list-public-http-$appName"
                Set-AppGatewayHttpListener -GatewayName $agwName -ResourceGroup $agwRG -ListenerName "list-public-http-$appName" -FrontendIpName "appGatewayFrontendIP" -HostName $listenerFqdn -FrontendPortName "fp-80"
            }

            Write-Host "  Creating redirect configuration: redirect-private-$appName"
            Set-AppGatewayRedirectConfig -GatewayName $agwName -ResourceGroup $agwRG -ConfigName "redirect-private-$appName" -TargetListenerName "list-private-$appName"

            # Redirect configurations
            if (-not $InternalOnly) {
                Write-Host "  Creating redirect configuration: redirect-public-$appName"
                Set-AppGatewayRedirectConfig -GatewayName $agwName -ResourceGroup $agwRG -ConfigName "redirect-public-$appName" -TargetListenerName "list-public-$appName"
            }
        }

        Write-Host "  Creating/updating routing rules for $appName"

        # Always anchor to private rule since it will always exist
        $next = Get-RulePriority -GatewayName $agwName -ResourceGroup $agwRG -RuleName "rule-private-$appName"

        # HTTPS rules - use fixed offsets so each rule type always has the same offset
        Write-Host "    Private HTTPS rule: rule-private-$appName (priority $next)"
        Set-AppGatewayRule -GatewayName $agwName -ResourceGroup $agwRG -RuleName "rule-private-$appName" -ListenerName "list-private-$appName" -AddressPoolName "ap-$appName" -HttpSettingsName "hs-$appName" -Priority $next

        if (-not $InternalOnly) {
            Write-Host "    Public HTTPS rule: rule-public-$appName (priority $($next + 1))"
            Set-AppGatewayRule -GatewayName $agwName -ResourceGroup $agwRG -RuleName "rule-public-$appName" -ListenerName "list-public-$appName" -AddressPoolName "ap-$appName" -HttpSettingsName "hs-$appName" -Priority ($next + 1)
        }

        if ($BrowserFriendlyRouting) {
            # HTTP redirect rules
            Write-Host "    Private HTTP redirect rule: rule-private-http-$appName (priority $($next + 2))"
            Set-AppGatewayRule -GatewayName $agwName -ResourceGroup $agwRG -RuleName "rule-private-http-$appName" -ListenerName "list-private-http-$appName" -RedirectConfigName "redirect-private-$appName" -Priority ($next + 2) -RuleType "Basic"

            if (-not $InternalOnly) {
                Write-Host "    Public HTTP redirect rule: rule-public-http-$appName (priority $($next + 3))"
                Set-AppGatewayRule -GatewayName $agwName -ResourceGroup $agwRG -RuleName "rule-public-http-$appName" -ListenerName "list-public-http-$appName" -RedirectConfigName "redirect-public-$appName" -Priority ($next + 3) -RuleType "Basic"
            }
        }

        if ($agwPrivateIp) {
            Write-Host "  Creating/updating private DNS record: $appName -> $agwPrivateIp"
            Set-PrivateDnsRecord -DnsZoneName $privateDnsZoneName -DnsZoneResourceGroup $privateDnsZoneRG -DnsZoneSubscriptionId $privateDnsZoneSubscriptionId -RecordName $dnsName -IpAddress $agwPrivateIp
        }
 
        Write-Host "  Completed integration for $($app.name)"
    }
 
    # Not thrilled having this here, but our configuration has to exist before we can remove the existing ones.
    # Remove-AppGatewayDefaultResources -GatewayName $agwName -ResourceGroup $agwRG

    Write-Host "Container App Integration completed for CAE: $($CaeConfig.name)"
}

<#
$subscriptionConfig = (Get-Parameters -filePath './Subscriptions/Ncontracts_DevTest/Subscription.json').subscriptionConfig.value
$environmentConfig = (Get-Parameters -filePath './Environments/Dev/Parameters/Poc01.json').environmentConfig.value
$caeConfig = $environmentConfig.caeConfigs[0]
Remove-ContainerAppIntegration -SubscriptionConfig $subscriptionConfig -EnvironmentConfig $environmentConfig -CaeConfig $caeConfig -ContainerAppName "myapp"
#>
function Remove-ContainerAppIntegration {
    param(
        [object]$SubscriptionConfig,
        [object]$EnvironmentConfig,
        [object]$CaeConfig,
        [string]$ContainerAppName = $null
    )

    Write-Host "Starting Container App Integration Cleanup for CAE: $($CaeConfig.name)"

    # App Gateway Config Properties
    $agwName = $caeConfig.appGateway.name
    $agwRG = $caeConfig.appGateway.resourceGroup
    Write-Host "Target Application Gateway: $agwName in resource group $agwRG"

    Write-Host "Verifying Application Gateway exists..."
    if (-not(Test-AgwResourceExists -ResourceGroup $agwRG -AppGateway $agwName -Type 'gateway')) {
        Write-Host "Application Gateway $agwName does not exist in resource group $agwRG. Skipping."
        return
    }
    Write-Host "Application Gateway found successfully"

    # CAE Config Properties
    $caeRG = $caeConfig.resourceGroup
    $caeName = $caeConfig.name
    $privateDnsZoneName = $caeConfig.privateDnsZone.name
    $privateDnsZoneRG = $caeConfig.privateDnsZone.resourceGroup
    $privateDnsZoneSubscriptionId = $caeConfig.privateDnsZone.subscriptionId

    Write-Host "Retrieving Container Apps from environment $caeName..."
    $apps = Get-Json @('containerapp','list','--resource-group',$caeRG,'--environment',$caeName,'-o','json')

    # Apply filter if provided
    if ($ContainerAppName) {
        Write-Host "Filtering for Container App: $ContainerAppName"
        $apps = $apps | Where-Object { $_.name -eq $ContainerAppName }
        if (-not $apps) {
            Write-Warning "Container App '$ContainerAppName' not found in environment $caeName"
            return
        }
    }

    # Filter out apps without ingress enabled
    $apps = $apps | Where-Object { $_.properties.configuration.ingress -and $_.properties.configuration.ingress.external }
    Write-Host "Found $($apps.Count) Container Apps with external ingress enabled"

    $environmentId = $EnvironmentConfig.environmentId
    if ($environmentId -eq 'prd') { $environmentId = '' } else { $environmentId = "-$environmentId" }
    foreach ($app in $apps) {
        $appName = "$($app.name)$environmentId"
        $dnsName = "$($appName)$environmentId"

        Write-Host "Removing integration for Container App: $($app.name) -> $appName"

        # Resources must be removed in reverse order of dependencies
        Write-Host "  Removing routing rules for $appName"

        # Remove HTTPS rules
        if (Test-AgwResourceExists -ResourceGroup $agwRG -AppGateway $agwName -Type 'rule' -Name "rule-public-$appName") {
            Write-Host "    Removing rule: rule-public-$appName"
            az network application-gateway rule delete `
                --gateway-name $agwName `
                --resource-group $agwRG `
                --name "rule-public-$appName" `
                --output none
        }

        if (Test-AgwResourceExists -ResourceGroup $agwRG -AppGateway $agwName -Type 'rule' -Name "rule-private-$appName") {
            Write-Host "    Removing rule: rule-private-$appName"
            az network application-gateway rule delete `
                --gateway-name $agwName `
                --resource-group $agwRG `
                --name "rule-private-$appName" `
                --output none
        }

        # Remove HTTP redirect rules (if they exist)
        if (Test-AgwResourceExists -ResourceGroup $agwRG -AppGateway $agwName -Type 'rule' -Name "rule-public-http-$appName") {
            Write-Host "    Removing rule: rule-public-http-$appName"
            az network application-gateway rule delete `
                --gateway-name $agwName `
                --resource-group $agwRG `
                --name "rule-public-http-$appName" `
                --output none
        }

        if (Test-AgwResourceExists -ResourceGroup $agwRG -AppGateway $agwName -Type 'rule' -Name "rule-private-http-$appName") {
            Write-Host "    Removing rule: rule-private-http-$appName"
            az network application-gateway rule delete `
                --gateway-name $agwName `
                --resource-group $agwRG `
                --name "rule-private-http-$appName" `
                --output none
        }

        Write-Host "  Removing redirect configurations for $appName"

        $redirectPublic = az network application-gateway redirect-config show `
            --gateway-name $agwName `
            --resource-group $agwRG `
            --name "redirect-public-$appName" `
            --query "id" `
            --output tsv 2>$null

        if ($redirectPublic) {
            Write-Host "    Removing redirect-config: redirect-public-$appName"
            az network application-gateway redirect-config delete `
                --gateway-name $agwName `
                --resource-group $agwRG `
                --name "redirect-public-$appName" `
                --output none
        }

        $redirectPrivate = az network application-gateway redirect-config show `
            --gateway-name $agwName `
            --resource-group $agwRG `
            --name "redirect-private-$appName" `
            --query "id" `
            --output tsv 2>$null

        if ($redirectPrivate) {
            Write-Host "    Removing redirect-config: redirect-private-$appName"
            az network application-gateway redirect-config delete `
                --gateway-name $agwName `
                --resource-group $agwRG `
                --name "redirect-private-$appName" `
                --output none
        }

        Write-Host "  Removing HTTP listeners for $appName"

        # Remove HTTPS listeners
        if (Test-AgwResourceExists -ResourceGroup $agwRG -AppGateway $agwName -Type 'http-listener' -Name "list-public-$appName") {
            Write-Host "    Removing listener: list-public-$appName"
            az network application-gateway http-listener delete `
                --gateway-name $agwName `
                --resource-group $agwRG `
                --name "list-public-$appName" `
                --output none
        }

        if (Test-AgwResourceExists -ResourceGroup $agwRG -AppGateway $agwName -Type 'http-listener' -Name "list-private-$appName") {
            Write-Host "    Removing listener: list-private-$appName"
            az network application-gateway http-listener delete `
                --gateway-name $agwName `
                --resource-group $agwRG `
                --name "list-private-$appName" `
                --output none
        }

        # Remove HTTP listeners (if they exist)
        if (Test-AgwResourceExists -ResourceGroup $agwRG -AppGateway $agwName -Type 'http-listener' -Name "list-public-http-$appName") {
            Write-Host "    Removing listener: list-public-http-$appName"
            az network application-gateway http-listener delete `
                --gateway-name $agwName `
                --resource-group $agwRG `
                --name "list-public-http-$appName" `
                --output none
        }

        if (Test-AgwResourceExists -ResourceGroup $agwRG -AppGateway $agwName -Type 'http-listener' -Name "list-private-http-$appName") {
            Write-Host "    Removing listener: list-private-http-$appName"
            az network application-gateway http-listener delete `
                --gateway-name $agwName `
                --resource-group $agwRG `
                --name "list-private-http-$appName" `
                --output none
        }

        if (Test-AgwResourceExists -ResourceGroup $agwRG -AppGateway $agwName -Type 'http-settings' -Name "hs-$appName") {
            Write-Host "  Removing HTTP settings: hs-$appName"
            az network application-gateway http-settings delete `
                --gateway-name $agwName `
                --resource-group $agwRG `
                --name "hs-$appName" `
                --output none
        }

        if (Test-AgwResourceExists -ResourceGroup $agwRG -AppGateway $agwName -Type 'probe' -Name "probe-$appName") {
            Write-Host "  Removing health probe: probe-$appName"
            az network application-gateway probe delete `
                --gateway-name $agwName `
                --resource-group $agwRG `
                --name "probe-$appName" `
                --output none
        }

        if (Test-AgwResourceExists -ResourceGroup $agwRG -AppGateway $agwName -Type 'address-pool' -Name "ap-$appName") {
            Write-Host "  Removing address pool: ap-$appName"
            az network application-gateway address-pool delete `
                --gateway-name $agwName `
                --resource-group $agwRG `
                --name "ap-$appName" `
                --output none
        }

        $existingRecord = az network private-dns record-set a show `
            --subscription $privateDnsZoneSubscriptionId `
            --zone-name $privateDnsZoneName `
            --resource-group $privateDnsZoneRG `
            --name $dnsName `
            --query "id" `
            --output tsv 2>$null

        if ($existingRecord) {
            Write-Host "  Removing private DNS record: $dnsName"
            az network private-dns record-set a delete `
                --subscription $privateDnsZoneSubscriptionId `
                --zone-name $privateDnsZoneName `
                --resource-group $privateDnsZoneRG `
                --name $dnsName `
                --yes `
                --output none
        }

        Write-Host "  Completed cleanup for $($app.name)"
    }

    Write-Host "Container App Integration Cleanup completed for CAE: $($CaeConfig.name)"
}