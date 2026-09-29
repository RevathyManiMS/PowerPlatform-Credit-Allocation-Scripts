#requires -Version 5.1

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)] [string] $EnvironmentId,
    [Parameter(Mandatory)] [string] $TenantId,
    [Parameter(Mandatory)] [string] $ClientId,
    [Parameter(Mandatory)] [securestring] $ClientSecret,
    [Parameter(Mandatory)] [string] $CurrencyType,
    [Parameter(Mandatory)] [ValidateRange(0, [int]::MaxValue)] [int] $Allocated,
    [Parameter(Mandatory)]
    [ValidateSet('Alert', 'PayGo', 'TenantPool', 'Deny')]
    [string] $EnforcementRuleType,
    [Parameter(Mandatory)] [bool] $EnforcementRuleEnabled
)

$ErrorActionPreference = 'Stop'
$plainSecret = [System.Net.NetworkCredential]::new('', $ClientSecret).Password

try {
    $token = Invoke-RestMethod -Method Post `
        -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" `
        -ContentType 'application/x-www-form-urlencoded' `
        -Body @{
            client_id     = $ClientId
            client_secret = $plainSecret
            scope         = 'https://api.powerplatform.com/.default'
            grant_type    = 'client_credentials'
        }
}
finally {
    $plainSecret = $null
}

$headers = @{
    Authorization = "Bearer $($token.access_token)"
    Accept        = 'application/json'
}

$body = @{
    environmentId       = $EnvironmentId
    currencyAllocations = @(
        @{
            currencyType     = $CurrencyType
            allocated        = $Allocated
            enforcementRules = @(
                @{
                    ruleType = $EnforcementRuleType
                    enabled  = $EnforcementRuleEnabled
                }
            )
        }
    )
} | ConvertTo-Json -Depth 5

Write-Host "`nPATCH body:"
$body

if ($PSCmdlet.ShouldProcess($EnvironmentId, 'Update allocation and enforcement rule')) {
    Invoke-RestMethod -Method Patch `
        -Uri 'https://api.powerplatform.com/licensing/allocationsByEnvironment?api-version=2024-10-01' `
        -Headers $headers `
        -ContentType 'application/json' `
        -Body $body |
        ConvertTo-Json -Depth 10
}
