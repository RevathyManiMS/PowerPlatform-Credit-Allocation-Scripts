#requires -Version 5.1

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)] [string] $CsvPath,
    [Parameter(Mandatory)] [string] $TenantId,
    [Parameter(Mandatory)] [string] $ClientId,
    [Parameter(Mandatory)] [securestring] $ClientSecret,
    [Parameter(Mandatory)] [string] $CurrencyType
)

$ErrorActionPreference = 'Stop'
$secret = [System.Net.NetworkCredential]::new('', $ClientSecret).Password
$token = Invoke-RestMethod -Method Post `
    -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" `
    -ContentType 'application/x-www-form-urlencoded' `
    -Body @{ client_id = $ClientId; client_secret = $secret; scope = 'https://api.powerplatform.com/.default'; grant_type = 'client_credentials' }
$secret = $null
$headers = @{ Authorization = "Bearer $($token.access_token)" }
$uri = 'https://api.powerplatform.com/licensing/allocationsByEnvironment?api-version=2024-10-01'

foreach ($row in Import-Csv $CsvPath) {
    $allocated = 0
    $enabled = $false
    if (-not [int]::TryParse($row.Allocated, [ref]$allocated) -or $allocated -lt 0) { throw "Invalid Allocated value for '$($row.EnvironmentId)'." }
    if (-not [bool]::TryParse($row.EnforcementRuleEnabled, [ref]$enabled)) { throw "Invalid EnforcementRuleEnabled value for '$($row.EnvironmentId)'." }
    if ($row.EnforcementRuleType -notin @('Alert', 'PayGo', 'TenantPool', 'Deny')) { throw "Invalid EnforcementRuleType for '$($row.EnvironmentId)'." }

    $body = @{
        environmentId = $row.EnvironmentId
        currencyAllocations = @(@{
            currencyType = $CurrencyType
            allocated = $allocated
            enforcementRules = @(@{ ruleType = $row.EnforcementRuleType; enabled = $enabled })
        })
    } | ConvertTo-Json -Depth 5

    if ($PSCmdlet.ShouldProcess($row.EnvironmentId, "Set $CurrencyType allocation to $allocated")) {
        Invoke-RestMethod -Method Patch -Uri $uri -Headers $headers -ContentType 'application/json' -Body $body
    }
}
