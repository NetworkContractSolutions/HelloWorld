function Validate-Context {
    param (
        [string] $subscriptionId = $null,
        [string] $username = $null
    )

    $sId = (az account show --query id -o tsv)
    if ($subscriptionId -and $sId -ne $subscriptionId) {
        Write-Error "Subscription context is not correct. Expected '$subscriptionId' but got '$sId'"
        exit 1
    }

    if ($env:servicePrincipalId) { # Requires the addSpnToEnvironment flag be enabled in the pipeline task
        $uName = (Get-IdentityName)
        if ($username -and $uName -ne $username) {
            Write-Error "Username context is not correct. Expected '$username' but got '$uName'"
            exit 1
        }
    }
}

function Get-Parameters {
    param (
        [string] $filePath
    )

    $envParameter = Get-ChildItem -Path $filePath
    $env = Get-Content $envParameter.FullName | ConvertFrom-Json;
    return $env.parameters;
}

function Get-IdentityName {
    if (-not($user) -and $env:servicePrincipalId) {
        # Requires the addSpnToEnvironment flag be enabled in the pipeline task
        $user = az ad sp show --id $env:servicePrincipalId --query "{displayName:displayName}" -o tsv
    }
    if (-not($user)) {
        # Non-SPN context, use the signed-in user
        $user = az ad signed-in-user show --query userPrincipalName --output tsv
    }
    return $user
}

function Execute-PSQL-Command-AsRole {
    param (
        [string] $role,
        [string] $serverName,
        [string] $dbName,
        [string] $command,
        [string] $user,
        [string] $password = $null,
        [hashtable] $params = @{},
        [switch] $usePgPassFile = $false,
        [switch] $failOnError = $false
    )

    $sql = @"
        BEGIN;

        SET ROLE dbadmin;
        GRANT $role TO current_user WITH INHERIT TRUE;
        RESET ROLE;

"@
    $sql += $command + "`n"

    $sql += @"

        SET ROLE dbadmin;
        REVOKE $role FROM current_user;
        RESET ROLE;

        COMMIT
"@

    Execute-PSQL -serverName $serverName -dbName $dbName -command $sql -user $user -password $password -params $params -usePgPassFile:$usePgPassFile -failOnError:$failOnError
}

function Execute-PSQL {
    param (
        [string] $serverName,
        [string] $dbName,
        [string] $command = $null,
        [string] $file = $null,
        [string] $user,
        [string] $password = $null,
        [hashtable] $params = @{},
        [switch] $usePgPassFile = $false,
        [switch] $failOnError = $false
    )
    if (-not($user)) { $user = Get-IdentityName }
    if (-not($serverName)) { Write-Error "serverName parameter is required"; exit 1; }
    if (-not($dbName)) { Write-Error "dbName parameter is required"; exit 1; }
    if (-not($command) -and -not($file)) { Write-Error "command or file parameter is required"; exit 1; }
    if ($command -and $file) { Write-Error "command and file parameters cannot both be specified"; exit 1; }

    if (!$usePgPassFile) {
        if ($password) {
            $env:PGPASSWORD = $password
            $env:PGPASSFILE = 'NUL'
        }
        else {
            $accessToken = az account get-access-token --resource https://ossrdbms-aad.database.windows.net --query accessToken --output tsv
            $env:PGPASSWORD = $accessToken
            $env:PGPASSFILE = 'NUL'
        }
    }

    $connArgs = "host=$serverName port=5432 dbname=$dbName user=$user sslmode=require"

    $paramList = @('-At')
    if ($null -ne $params -and $params.Count -gt 0) {
        foreach ($kvp in $params.GetEnumerator()) {
            $key   = $kvp.Key
            $value = $kvp.Value -replace "'", "''"   # escape single quotes
            $value = "$value"                        # wrap in single quotes

            $paramList += '-v'                       # first arg: the switch
            $paramList += "$key=$value"          # second arg: assignment
        }
    }

    if ($failOnError) {
        $paramList += '-v'
        $paramList += 'ON_ERROR_STOP=1'
    }

    if ($file) {
        $paramList += '-f'
        $paramList += $file

        return & psql @paramList $connArgs
    }
    else {
        $command += "`n\q"
        if ($paramList.Count -gt 0) {
            return $command | & psql @paramList $connArgs
        }
        else {
            return $command | & psql $connArgs
        }
    }

    $exitCode = $LASTEXITCODE
    if ($failOnError -and $exitCode -ne 0) {
        throw "An error occurred executing the last command"
    }

    Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
    Remove-Item Env:PGPASSFILE -ErrorAction SilentlyContinue
}

function Ensure-Secret {
    param (
        [string] $vaultName,
        [string] $secretName
    )

    $toDashes = $secretName -replace '_', '-'
    $existing = az keyvault secret show --vault-name $vaultName --name $toDashes --query value --output tsv 2>$null

    if ($existing) { return $existing }

    $softDeleted = az keyvault secret show-deleted --name $toDashes --vault-name $vaultName --query id --output tsv 2>$null

    # Recover the secret if it was soft deleted.  Then we overwrite the value with a new password.
    # This is a workaround for the fact that we cannot create a new secret with the same name as a deleted one.
    if ($softDeleted) {
        try {
            az keyvault secret recover --name $toDashes --vault-name $vaultName > $null
        } catch {
            Write-Error "An error occurred recovering secret ($toDashes) from keyvault ($vaultName) : $_"
            exit 1
        }
    }

    $password = [guid]::NewGuid().ToString()
    try {
        az keyvault secret set --name $toDashes --vault-name $vaultName --value $password > $null
    } catch {
        Write-Error "An error occurred adding secret ($toDashes) to keyvault ($vaultName) : $_"
        exit 1
    }
    return $password
}

# Revoke public permissions: https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/concepts-security
function Init-PSQLDatabase {
    param (
        [string] $serverName,
        [string] $dbName,
        [array] $azureExtensions = @()
    )

    # Create database as single command.  Cannot be part of a transaction block.
    $command = @"
        \echo 'Create Database...';
        SELECT FORMAT('CREATE DATABASE %I;', '$dbName')
        FROM (SELECT 1) AS dummy
        WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = '$dbName');
        \gexec
"@
    Execute-PSQL -serverName $serverName -dbName "postgres" -command $command

    $command = @"
        -- Lock PUBLIC down
        SELECT FORMAT('REVOKE CREATE, TEMPORARY ON DATABASE %I FROM PUBLIC', '$dbName');
        \gexec

        -- Baseline role permissions
        SELECT FORMAT('GRANT ALL ON DATABASE %I TO %I_dbo', '$dbName', '$dbName');
        \gexec
        SELECT FORMAT('GRANT CONNECT,TEMPORARY ON DATABASE %I TO %I_ro', '$dbName', '$dbName');
        \gexec
        SELECT FORMAT('GRANT CONNECT,TEMPORARY ON DATABASE %I TO %I_rw', '$dbName', '$dbName');
        \gexec
"@
    Execute-PSQL -serverName $serverName -dbName "postgres" -command $command

    $dboRole = "${dbName}_dbo"
    $command = @"
        \echo 'Set Ownership of Database to dbo...';
        SELECT FORMAT('ALTER DATABASE %I OWNER TO %I', '$dbName', '$dboRole');
        \gexec

        GRANT USAGE, CREATE ON SCHEMA public TO dbadmin;

        SELECT format('GRANT CREATE ON DATABASE %I TO dbadmin;', '$dbName');
        \gexec
"@
    Execute-PSQL-Command-AsRole -role $dboRole -serverName $serverName -dbName $dbName -command $command

    if ($azureExtensions.Length -gt 0) {
        $command = ""
        foreach ($extension in $azureExtensions) {
            $command += @"
                \echo 'Installing extension: $extension';
                CREATE EXTENSION IF NOT EXISTS "$extension" WITH SCHEMA public;
"@
        }

        Execute-PSQL -serverName $serverName -dbName $dbName -command $command
    }

    # Add system scripts to public schema
    $command = "SET ROLE dbadmin;`n"
    $systemScripts = Get-ChildItem -Path './Environments/Scripts/PSQL/System/*.sql'
    foreach ($script in $systemScripts) {
        $command += "\i ./Environments/Scripts/PSQL/System/$($script.Name)`n"
    }
    $command += "RESET ROLE;`n"
    Execute-PSQL -serverName $serverName -dbName $dbName -command $command

    # Initialize permissions on public schema
    $command = "SELECT init_public_schema_permission_v1();`n"
    Execute-PSQL -serverName $serverName -dbName $dbName -command $command
}

function Get-FQDNServerName {
    param (
        [string] $serverName,
        [string] $resourceGroup
    )

    $fs = (az postgres flexible-server show --name $serverName --resource-group $resourceGroup) | ConvertFrom-Json
    if ($null -eq $fs) {
      Write-Error "Flexible Server does not exist $serverName in $resourceGroup"
      return $null;
    }

    return $fs.fullyQualifiedDomainName
}

function Execute-ServerCleanUp {
    param (
        [string] $serverName,
        [switch] $preCleanup = $false,
        [switch] $postCleanup = $false
    )
    if ($preCleanup -and $postCleanup) {
        Write-Error "preCleanup and postCleanup cannot both be specified"
        return;
    }

    $dateString = (Get-Date).ToUniversalTime().AddHours(-5).ToString("yyyyMMdd")
    if ($preCleanup) { $cleanupPath = "PreServer" } else { $cleanupPath = "PostServer" }

    $scriptPath = "./Environments/Scripts/PSQL/Cleanup/$cleanupPath/$dateString.sql"
    $cleanUpScript = Get-ChildItem -Path $scriptPath -ErrorAction SilentlyContinue
    if ($null -eq $cleanUpScript) { return; }

    $command = "\echo 'Run $cleanupPath Clean Up $dateString ...';`n"
    $command += "\i $scriptPath`n"
    Execute-PSQL -serverName $serverName -dbName "postgres" -command $command
}

function Execute-DatabaseCleanUp {
    param (
        [object] $serverName,
        [string] $dbName,
        [switch] $preCleanup = $false,
        [switch] $postCleanup = $false
    )
    if ($preCleanup -and $postCleanup) {
        Write-Error "preCleanup and postCleanup cannot both be specified"
        return;
    }

    $dateString = (Get-Date).ToUniversalTime().AddHours(-5).ToString("yyyyMMdd")
    if ($preCleanup) { $cleanupPath = "PreDatabase" } else { $cleanupPath = "PostDatabase" }

    $scriptPath = "./Environments/Scripts/PSQL/Cleanup/$cleanupPath/$dateString.sql"
    $cleanUpScript = Get-ChildItem -Path $scriptPath -ErrorAction SilentlyContinue
    if ($null -eq $cleanUpScript) { return; }

    $command = "\echo 'Run $cleanupPath Clean Up $dateString for $dbName...';`n"
    $command += "\i $scriptPath`n"
    Execute-PSQL -serverName $serverName -dbName $dbName -command $command
}

# All paths must support:
# 1) New uninitialized server
# 2) Server on older version needing to be upgraded
# 3) Server on current version no changes needed
# Private function.  Callable by flexible server administrator logins (Dev-SecOps-SPN, Prod-SecOps-SPN)
function Init-PSQLServer {
    param (
        [object] $envConfig,
        [object] $psqlConfig,
        [array] $databaseNames = @()
    )
    $serverName = Get-FQDNServerName -serverName $psqlConfig.name -resourceGroup $psqlConfig.resourceGroup
    Execute-ServerCleanUp -preCleanup -serverName $serverName

    $adminPrincipals = @($psqlConfig.permissions.adminPrincipalNames ?? @()) -join ','
    $limitedPrincipalName = $envConfig.limitedPrincipalName
    $readAllServerRoles = @($psqlConfig.permissions.readAllServerRoles ?? @()) -join ','
    $command = @"
        \echo 'Setting up parameters...'

        SET custom.adminPrincipals TO '$adminPrincipals';
        SET custom.limitedPrincipalName TO '$limitedPrincipalName';
        SET custom.readAllServerRoles TO '$readAllServerRoles';

        \i ./Environments/Scripts/PSQL/Init/add_server_roles.sql;`n
"@

    Execute-PSQL -serverName $serverName -dbName "postgres" -command $command

    $permissions = $psqlConfig.permissions;
    $withDeveloperGroups = ($permissions.withDeveloperGroups ?? "").ToString().Trim().ToLower() -eq "true"
    $passwordKV = $psqlConfig.passwordKeyVault
    $adminKeyVault = $psqlConfig.adminKeyVault
    $dboPrincipals = ($permissions.dboPrincipalNames ?? @()) -join ','
    $psqlId = $psqlConfig.id

    # Set passwords for server-level login roles
    $serverLoginRoles = @($psqlConfig.permissions.readAllServerRoles ?? @())
    $command = ""
    foreach ($serverRole in $serverLoginRoles) {
        $secretName = $psqlId + '_' + $serverRole
        $p = (Ensure-Secret -vaultName $adminKeyVault -secretName $secretName)
        $command += "ALTER USER ""$serverRole"" WITH PASSWORD '$p';`n"
    }
    if ($command) {
        Execute-PSQL -serverName $serverName -dbName "postgres" -command $command
    }

    foreach ($dbName in $databaseNames) {
        $roNames = @($permissions.roPrincipalNames)
        $rwNames = @($permissions.rwPrincipalNames)
        if ($withDeveloperGroups) {
            $roNames = $roNames + "AzureProdDB_psql_${dbName}_ReadOnly"
            $rwNames = $rwNames + "AzureProdDB_psql_${dbName}_ReadWrite"
        }

        $roPrincipals = ($roNames ?? @()) -join ','
        $rwPrincipals = ($rwNames ?? @()) -join ','

        $command = @"
            \echo 'Setting up parameters...'

            SET custom.dbName TO '$dbName';
            SET custom.roPrincipals TO '$roPrincipals';
            SET custom.rwPrincipals TO '$rwPrincipals';
            SET custom.dboPrincipals TO '$dboPrincipals';

            \i ./Environments/Scripts/PSQL/Init/add_database_roles.sql;`n
"@

        Execute-PSQL -serverName $serverName -dbName "postgres" -command $command

        $command = ""
        foreach ($login in @("app", "deploy")) {
            $secretName = $psqlId + '_' + $dbName + '_' + $login
            $dbNameLogin = $dbName + '_' + $login

            $p = (Ensure-Secret -vaultName $passwordKV -secretName $secretName)
            $command += "ALTER USER ""$dbNameLogin"" WITH PASSWORD '$p';`n"
        }
        Execute-PSQL -serverName $serverName -dbName "postgres" -command $command
    }
}

# Public function.  Callable by flexible server administrator logins (Dev-SecOps-SPN, Prod-SecOps-SPN)
function Cleanup-PSQLServers {
    param (
        [array] $environments,
        [string] $paramsFolder
    )

    $envParameters = Get-ChildItem -Path ($paramsFolder.Trim('/') + '/*.json')
    $envParameters = $envParameters | Where-Object { $_.BaseName.ToLower() -in $environments }
    
    foreach ($envParameter in $envParameters) {
        $baseName = $envParameter.BaseName
        $envConfig = (Get-Parameters -filePath $envParameter.FullName).environmentConfig.value;
        
        foreach ($psqlConfig in $envConfig.psqlConfigs) {
            Write-Host "-----------------------------------------------------"
            Write-Host "Cleanup-PSQLServers $baseName"

            $serverName = Get-FQDNServerName -serverName $psqlConfig.name -resourceGroup $psqlConfig.resourceGroup
            Execute-ServerCleanUp -postCleanup -serverName $serverName
        }
    }
}

# Public function.  Callable by flexible server administrator logins (Dev-SecOps-SPN, Prod-SecOps-SPN)
function Init-PSQLServers {
    param (
        [array] $environments,
        [string] $paramsFolder,
        [string[]] $databaseNames = @()
    )

    $envParameters = Get-ChildItem -Path ($paramsFolder.Trim('/') + '/*.json')
    $envParameters = $envParameters | Where-Object { $_.BaseName.ToLower() -in $environments }
    
    foreach ($envParameter in $envParameters) {
        $baseName = $envParameter.BaseName
        $envConfig = (Get-Parameters -filePath $envParameter.FullName).environmentConfig.value;
        
        foreach ($psqlConfig in $envConfig.psqlConfigs) {
            Write-Host "-----------------------------------------------------"
            Write-Host "Init-PSQLServer $baseName"

            $dbNames = @($psqlConfig.databases | ForEach-Object { $_.name }) # Extract database names
            if ($databaseNames) {
                $filter = @($databaseNames)
                $dbNames = $dbNames.Where({$filter -contains $_});
            }

            Init-PSQLServer -envConfig $envConfig -psqlConfig $psqlConfig -databaseNames $dbNames
        }
    }
}

function Init-PSQLDatabaseV2 {
    param (
        [object] $envConfig,
        [object] $psqlConfig,
        [string] $dbName
    )
    $globalAzureExtensions = $psqlConfig.globalAzureExtensions ?? @()

    $serverName = Get-FQDNServerName -serverName $psqlConfig.name -resourceGroup $psqlConfig.resourceGroup
    Execute-DatabaseCleanUp -preCleanup -serverName $serverName -dbName $dbName

    Write-Host "-----------------------------------------------------"
    Write-Host "Init-PSQLDatabaseV2 $dbName"

    $dbAzureExtensions = $db.azureExtensions ?? @()
    $azureExtensions = $dbAzureExtensions + $globalAzureExtensions | Where-Object { $_ -and $_.Trim() -ne "" } | ForEach-Object { $_.Trim() } | Sort-Object -Unique

    Init-PSQLDatabase -serverName $serverName -dbName $dbName -azureExtensions $azureExtensions

    Execute-DatabaseCleanUp -postCleanup -serverName $serverName -dbName $dbName
}

# Public function.  Callable by server administrator that inherits from the role dbadmin (Dev-DevOpsLimited-SPN, Prod-DevOpsLimited-SPN, Azuredevdb_psql_Admins, Azureproddb_psql_Admins, etc)
function Init-PSQLDatabasesV2 {
    param (
        [array] $environments,
        [string] $paramsFolder,
        [array] $databaseNames = @()
    )
    
    $envParameters = Get-ChildItem -Path ($paramsFolder.Trim('/') + '/*.json')
    $envParameters = $envParameters | Where-Object { $_.BaseName.ToLower() -in $environments }
    
    foreach ($envParameter in $envParameters) {
        $baseName = $envParameter.BaseName
        $envConfig = (Get-Parameters -filePath $envParameter.FullName).environmentConfig.value;
        
        foreach ($psqlConfig in $envConfig.psqlConfigs) {
            Write-Host "-----------------------------------------------------"
            Write-Host "Init-PSQLServer $baseName"

            $databases = $psqlConfig.databases
            if ($databaseNames -and $databaseNames.Length -ne 0) {
                $databases = $databases | Where-Object { $_.name -in $databaseNames }
            }

            foreach ($db in $databases) {
                $dbName = $db.name

                Init-PSQLDatabaseV2 -envConfig $envConfig -psqlConfig $psqlConfig -dbName $dbName
            }
        }
    }
}

function Grant-PostgresAccess {
    param (
        [string] $dbName,
        [string] $username,
        [string] $accessType
    )

    $dbName = $dbName.ToLower()
    $username = $username.ToLower()
    $accessSuffix = $accessType.ToLower() -eq 'readonly' ? 'ro' : 'rw'
    $role = "${dbName}_${accessSuffix}"
    $validUntil = (Get-Date).ToUniversalTime().AddHours(4).ToString("yyyy-MM-dd'T'HH:mm:sszzz")

    $envConfig = (Get-Parameters -filePath './Environments/Prod/Parameters/Production.json').environmentConfig.value;
    $psqlConfig = $envConfig.psqlConfigs | Where-Object {
        $_.databases | Where-Object { $_.name -eq $dbName }
    }

    if ($null -eq $psqlConfig) {
        Write-Error "Postgres config not found for database $databaseName"
        return
    }

    $serverName = Get-FQDNServerName -serverName $psqlConfig.name -resourceGroup $psqlConfig.resourceGroup

    Write-Host "-----------------------------------------------------"
    Write-Host "Grant-PostgresAccess"

    $command = @"
        \echo 'Setting up parameters...'

        SET custom.username TO :'username';
        SET custom.validUntil TO :'validUntil';
        SET custom.role TO :'role';

        \i ./Environments/Scripts/PSQL/Commands/grant_until.sql;`n
"@

    $params = @{
        username = $username
        role = $role
        validUntil = $validUntil
    }

    Execute-PSQL -serverName $serverName -dbName "postgres" -command $command -params $params
}

function Get-EnvironmentConfigs {
    param(
        [string]$EnvironmentNames,
        [string]$ParametersPath
    )

    $envParameters = Get-ChildItem -Path $ParametersPath
    $environments = $EnvironmentNames.Split(',')
    $envParameters = $envParameters | Where-Object { $_.BaseName.ToLower() -in $environments }

    $configs = @()
    foreach ($envParameter in $envParameters) {
        $envConfig = (Get-Parameters -filePath $envParameter.FullName).environmentConfig.value
        @("applicationGateways", "caeConfigs", "psqlConfigs", "resourceGroups") | ForEach-Object {
            if (-not (Get-Member -InputObject $envConfig -Name $_ -MemberType Properties)) {
                $envConfig | Add-Member -MemberType NoteProperty -Name $_ -Value @()
            }
        }

        $configs += $envConfig
    }
    return $configs
}