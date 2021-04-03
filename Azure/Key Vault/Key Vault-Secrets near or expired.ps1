# Key Vault Secrets expiration monitor and post alert into a Teams Channel 
# Version: 1.0
# Developed by: Felipe Augusto [felipeaugustol.com] | Cloud Solutions Architect 
# Created: 09th March, 2020
# Last Change: 09th March, 2020
# Requirements:
#   - Azure Automation Account

$connectionName = "AzureRunAsConnection"
try
{
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName       
    "Logging in to Azure..."
    Connect-AzAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
}
catch {
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else{
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}


$DaysNearExpiration = 30
 
$ExpiredSecrets = @()
$NearExpirationSecrets = @()

$ExpiredKeys = @()
$NearExpirationKeys = @()
 
#gather all key vaults from subscription
if ($VaultName) {
    $KeyVaults = Get-AzKeyVault -VaultName $VaultName
}
else {
    $KeyVaults = Get-AzKeyVault
}
#check date which will notify about expiration
$ExpirationDate = (Get-Date (Get-Date).AddDays($DaysNearExpiration) -Format yyyyMMdd)
$CurrentDate = (Get-Date -Format yyyyMMdd)
 
# iterate across all key vaults in subscription
foreach ($KeyVault in $KeyVaults) {
    # gather all secrets in each key vault
    $SecretsArray = Get-AzKeyVaultSecret -VaultName $KeyVault.VaultName
    foreach ($secret in $SecretsArray) {
        # check if expiration date is set
        if ($secret.Expires) {
            $secretExpiration = Get-date $secret.Expires -Format yyyyMMdd
            # check if expiration date set on secret is before notify expiration date
            if ($ExpirationDate -gt $secretExpiration) {
                # check if secret did not expire yet but will expire soon
                if ($CurrentDate -lt $secretExpiration) {
                    $NearExpirationSecrets += New-Object PSObject -Property @{
                        Name           = $secret.Name;
                        Category       = 'SecretNearExpiration';
                        KeyVaultName   = $KeyVault.VaultName;
                        ExpirationDate = $secret.Expires;
                    }
                }
                # secret is already expired
                else {
                    $ExpiredSecrets += New-Object PSObject -Property @{
                        Name           = $secret.Name;
                        Category       = 'SecretNearExpiration';
                        KeyVaultName   = $KeyVault.VaultName;
                        ExpirationDate = $secret.Expires;
                    }
                }
            }
        }
    }
    # gather all Keys in each key vault
    $keyarray = Get-AzKeyVaultKey -VaultName $KeyVault.VaultName
    foreach ($key in $keyarray) {
        # check if expiration date is set
        if ($key.Expires) {
            $keyExpiration = Get-date $key.Expires -Format yyyyMMdd
            # check if expiration date set on key is before notify expiration date
            if ($ExpirationDate -gt $keyExpiration) {
                # check if key did not expire yet but will expire soon
                if ($CurrentDate -lt $keyExpiration) {
                    $NearExpirationKeys += New-Object PSObject -Property @{
                        Name           = $key.Name;
                        Category       = 'KeyNearExpiration';
                        KeyVaultName   = $KeyVault.VaultName;
                        ExpirationDate = $key.Expires;
                    }
                }
                # key is already expired
                else {
                    $ExpiredKeys += New-Object PSObject -Property @{
                        Name           = $key.Name;
                        Category       = 'KeyNearExpiration';
                        KeyVaultName   = $KeyVault.VaultName;
                        ExpirationDate = $Key.Expires;
                    }
                }
            }
        }
    }
}
 
Write-Output "Total number of expired secrets: $($ExpiredSecrets.Count). Find more details below:"
$ExpiredSecrets

Write-Output "-------------------------------------------------------------------------"
  
Write-Output "Total number of secrets near expiration: $($NearExpirationSecrets.Count). Find more details below:"
$NearExpirationSecrets

Write-Output "-------------------------------------------------------------------------"

Write-Output "Total number of expired Keys: $($ExpiredKeys.Count). Find more details below:"
$ExpiredKeys

Write-Output "-------------------------------------------------------------------------"
  
Write-Output "Total number of secrets near expiration: $($NearExpirationKeys.Count). Find more details below:"
$NearExpirationKeys

#Teams Webhook
$TeamsChannelUri = "[Insert Webhook Link here, use a encrypted variable]"


if ($ExpiredSecrets.Count -gt 0){
    $body = @"
    {
        "@type": "MessageCard",
        "@context": "https://schema.org/extensions",
        "summary": "Key Vault Alert",
        "themeColor": "0072C6",
        "title": "Key Vault Secret expired",
         "sections": [
            {
            
                "facts": [
                    {
                        "name": "Key Vault Name:",
                        "value": "$($ExpiredSecrets.keyvaultname)"
                    },
                    {
                        "name": "Secret Name:",
                        "value": "$($ExpiredSecrets.name)"
                    },
                    {
                        "name": "Expiration Date:",
                        "value": "$($ExpiredSecrets.expirationdate)"
                    }
                ],
                "text": "Key Vault Secret expired"
            }
        ]
    }
"@

    Invoke-RestMethod -uri $TeamsChannelUri -Method Post -body $body -ContentType 'application/json'
}

if ($NearExpirationSecrets.Count -gt 0)
{
    $body = @"
    {
        "@type": "MessageCard",
        "@context": "https://schema.org/extensions",
        "summary": "Key Vault Alert",
        "themeColor": "0072C6",
        "title": "Key Vault Secret near to expire",
         "sections": [
            {
            
                "facts": [
                    {
                        "name": "Key Vault Name:",
                        "value": "$($NearExpirationSecrets.keyvaultname)"
                    },
                    {
                        "name": "Secret Name:",
                        "value": "$($NearExpirationSecrets.name)"
                    },
                    {
                        "name": "Expiration Date:",
                        "value": "$($NearExpirationSecrets.expirationdate)"
                    }
                ],
                "text": "Key Vault Secret will expire in 30 days"
            }
        ]
    }
"@
    Invoke-RestMethod -uri $TeamsChannelUri -Method Post -body $body -ContentType 'application/json'
}
if ($ExpiredKeys.Count -gt 0)
{
    $body = @"
    {
        "@type": "MessageCard",
        "@context": "https://schema.org/extensions",
        "summary": "Key Vault Alert",
        "themeColor": "0072C6",
        "title": "Key Vault Key expired",
         "sections": [
            {
            
                "facts": [
                    {
                        "name": "Key Vault Name:",
                        "value": "$($ExpiredKeys.keyvaultname)"
                    },
                    {
                        "name": "Key Name:",
                        "value": "$($ExpiredKeys.name)"
                    },
                    {
                        "name": "Expiration Date:",
                        "value": "$($ExpiredKeys.expirationdate)"
                    }
                ],
                "text": "Key Vault Key expired"
            }
        ]
    }
"@

    Invoke-RestMethod -uri $TeamsChannelUri -Method Post -body $body -ContentType 'application/json'
}
if ($NearExpirationKeys.Count -gt 0)
{
    $body = @"
    {
        "@type": "MessageCard",
        "@context": "https://schema.org/extensions",
        "summary": "Key Vault Alert",
        "themeColor": "0072C6",
        "title": "Key Vault Key near to expire",
         "sections": [
            {
            
                "facts": [
                    {
                        "name": "Key Vault Name:",
                        "value": "$($NearExpirationKeys.keyvaultname)"
                    },
                    {
                        "name": "Items Name:",
                        "value": "$($NearExpirationKeys.name)"
                    },
                    {
                        "name": "Expiration Date:",
                        "value": "$($NearExpirationKeys.expirationdate)"
                    }
                ],
                "text": "Key Vault Key will expire in 30 days"
            }
        ]
    }
"@

    Invoke-RestMethod -uri $TeamsChannelUri -Method Post -body $body -ContentType 'application/json'
}