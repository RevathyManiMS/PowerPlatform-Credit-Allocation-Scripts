# Power Platform Credit Allocation Scripts

PowerShell scripts for managing Power Platform credit allocations and capacity-overage behavior for one or multiple environments.

The scripts can:

- Set the credits allocated to an environment.
- Enable or disable an enforcement rule.
- Prevent an environment from drawing credits from the tenant capacity pool.
- Apply allocation settings to multiple environments from a CSV file.
- Preview changes safely using PowerShell's `-WhatIf` option.

## Scripts

| Script | Description |
|---|---|
| `Set-PowerPlatformSingleEnvironmentAllocation.ps1` | Updates the allocation and enforcement rule for one Power Platform environment. |
| `Set-PowerPlatformEnvironmentAllocationsFromCsv.ps1` | Updates multiple Power Platform environments using values from a CSV file. |

## Capacity-overage behavior

Power Platform environments can have the following capacity-overage setting enabled:

> **Draw from the available capacity in my tenant**

To prevent an environment from consuming credits from the tenant pool, configure:

```text
Allocated = 0
EnforcementRuleType = TenantPool
EnforcementRuleEnabled = false
```

This produces an API request similar to:

```json
{
  "environmentId": "00000000-0000-0000-0000-000000000000",
  "currencyAllocations": [
    {
      "currencyType": "MCSMessages",
      "allocated": 0,
      "enforcementRules": [
        {
          "ruleType": "TenantPool",
          "enabled": false
        }
      ]
    }
  ]
}
```

When the `TenantPool` rule is disabled, the environment cannot draw from the tenant's available capacity after its allocated capacity reaches zero.

> [!CAUTION]
> Disabling access to the tenant pool can restrict or interrupt workloads after the environment's allocated credits are exhausted. Test this behavior before applying it to production environments.

## Allocation values

Supported allocation values are:

- `0`, to allocate no environment-specific credits.
- A value greater than or equal to `500`.

Examples:

```text
0
500
1000
2500
```

Do not use values between `1` and `499`.

The requested allocation must also be available in the tenant. The Power Platform API might reject an allocation that exceeds the tenant's available capacity.

## Power Platform API

The scripts use the Microsoft Power Platform Licensing REST API.

### Get allocations for an environment

```http
GET https://api.powerplatform.com/licensing/allocationsByEnvironment/{environmentId}?api-version=2024-10-01
```

Documentation:

[Get Allocations By Environment](https://learn.microsoft.com/en-us/rest/api/power-platform/licensing/allocations-by-environment/get-allocations-by-environment)

### Update allocations for an environment

```http
PATCH https://api.powerplatform.com/licensing/allocationsByEnvironment?api-version=2024-10-01
```

Documentation:

[Update Allocations By Environment](https://learn.microsoft.com/en-us/rest/api/power-platform/licensing/allocations-by-environment/update-allocations-by-environment)

## Prerequisites

Before using the scripts, you need:

- PowerShell 5.1 or newer.
- A Microsoft Entra tenant.
- Permission to create or manage app registrations.
- A Microsoft Entra app registration.
- A client secret for the app registration.
- Power Platform administrative access.
- Permission to read and update Power Platform licensing allocations.
- The service principal registered as a Power Platform management application.

# Create the Microsoft Entra app registration using the UI

The scripts authenticate using a Microsoft Entra application and a client secret.

## 1. Open Microsoft Entra admin center

1. Open the [Microsoft Entra admin center](https://entra.microsoft.com).
2. Sign in using an account that can create app registrations.
3. Confirm that you are working in the correct tenant by selecting your profile in the upper-right corner.

## 2. Create the app registration

1. Go to:

   **Identity** > **Applications** > **App registrations**

2. Select **New registration**.
3. Enter an application name, for example:

   ```text
   Power Platform Credit Allocation
   ```

4. Under **Supported account types**, select:

   ```text
   Accounts in this organizational directory only
   ```

5. Leave **Redirect URI** empty because the scripts use client-secret authentication.
6. Select **Register**.

## 3. Record the application identifiers

After registration, the application's **Overview** page opens.

Copy and securely record:

- **Application (client) ID**
- **Directory (tenant) ID**

These values are passed to the scripts as:

```powershell
-TenantId "YOUR-DIRECTORY-TENANT-ID"
-ClientId "YOUR-APPLICATION-CLIENT-ID"
```

Do not use the app registration's **Object ID** as the Client ID.

## 4. Add Power Platform API permissions

1. In the app registration, select **API permissions**.
2. Select **Add a permission**.
3. Select **APIs my organization uses**.
4. Search for:

   ```text
   Power Platform API
   ```

5. If multiple results appear, select the API with this application ID:

   ```text
   8578e004-a5c6-46e7-913e-12f58912df43
   ```

6. Add the permissions required by your scenario.

For allocation updates, add:

```text
Licensing.Allocations.ReadWrite
```

For read-only allocation operations, add:

```text
Licensing.Allocations.Read
```

If the application also needs to read environment information, add:

```text
EnvironmentManagement.Environments.Read
```

7. Select **Add permissions**.
8. Return to the **API permissions** page.
9. Select **Grant admin consent for your organization**.
10. Select **Yes** to confirm.

The permission status should show:

```text
Granted for <your organization>
```

> [!NOTE]
> Granting API permissions does not by itself register the application as a Power Platform management application. Complete the Power Platform registration steps later in this guide.

## 5. Create the client secret

1. In the app registration, select **Certificates & secrets**.
2. Select the **Client secrets** tab.
3. Select **New client secret**.
4. Enter a description, for example:

   ```text
   Power Platform allocation scripts
   ```

5. Select an expiration period that follows your organization's security policy.
6. Select **Add**.
7. Immediately copy the secret from the **Value** column.

> [!IMPORTANT]
> Copy the client secret's **Value**, not its **Secret ID**. The value is shown only once.

Do not put the client secret in:

- A PowerShell script.
- A CSV file.
- A README file.
- A Git commit.
- A public or private GitHub repository.

## 6. Confirm the Enterprise application exists

Creating an app registration normally creates a corresponding Enterprise application.

1. Go to:

   **Identity** > **Applications** > **Enterprise applications**

2. Select **All applications**.
3. Search using the application name or Application Client ID.
4. Open the matching Enterprise application.
5. Confirm that its **Application ID** matches the Client ID recorded earlier.

The Enterprise application's **Object ID** is different from the Application Client ID.

# Register the application with Power Platform

The application must also be registered as a Power Platform management application.

This step requires:

- Windows PowerShell 5.1.
- A Power Platform Administrator or Global Administrator account.

## 1. Open Windows PowerShell 5.1

Verify the PowerShell edition:

```powershell
$PSVersionTable.PSEdition
```

The result should be:

```text
Desktop
```

If you are using PowerShell 7, start Windows PowerShell by running:

```powershell
powershell.exe
```

## 2. Temporarily permit module scripts

```powershell
Set-ExecutionPolicy `
    -Scope Process `
    -ExecutionPolicy Bypass `
    -Force
```

This setting applies only to the current PowerShell process.

## 3. Install the Power Platform modules

```powershell
Install-Module `
    -Name Microsoft.PowerApps.PowerShell `
    -Scope CurrentUser `
    -Force `
    -AllowClobber

Install-Module `
    -Name Microsoft.PowerApps.Administration.PowerShell `
    -Scope CurrentUser `
    -Force `
    -AllowClobber
```

Import the modules:

```powershell
Import-Module Microsoft.PowerApps.PowerShell -Force
Import-Module Microsoft.PowerApps.Administration.PowerShell -Force
```

## 4. Register the management application

```powershell
$tenantId = "YOUR-DIRECTORY-TENANT-ID"
$clientId = "YOUR-APPLICATION-CLIENT-ID"

Add-PowerAppsAccount `
    -Endpoint prod `
    -TenantID $tenantId

New-PowerAppManagementApp `
    -ApplicationId $clientId
```

Sign in with a Power Platform Administrator or Global Administrator account when prompted.

Microsoft documentation:

[Creating a service principal application using PowerShell](https://learn.microsoft.com/en-us/power-platform/admin/powershell-create-service-principal)

> [!WARNING]
> A Power Platform management application receives broad tenant-management access. Use a dedicated app registration and protect its credentials.

# Enter the client secret securely

Enter the client secret as a PowerShell `SecureString`:

```powershell
$clientSecret = Read-Host "Enter client secret" -AsSecureString
```

Pass it to a script using:

```powershell
-ClientSecret $clientSecret
```

The secret is not displayed while it is entered.

Do not place the secret directly in a command, script, or CSV file.

# Update one environment

Use `Set-PowerPlatformSingleEnvironmentAllocation.ps1` to update one environment.

Always preview the request with `-WhatIf`:

```powershell
$clientSecret = Read-Host "Enter client secret" -AsSecureString

.\Set-PowerPlatformSingleEnvironmentAllocation.ps1 `
    -EnvironmentId "00000000-0000-0000-0000-000000000000" `
    -TenantId "11111111-1111-1111-1111-111111111111" `
    -ClientId "22222222-2222-2222-2222-222222222222" `
    -ClientSecret $clientSecret `
    -CurrencyType MCSMessages `
    -Allocated 0 `
    -EnforcementRuleType TenantPool `
    -EnforcementRuleEnabled $false `
    -WhatIf
```

Review the displayed PATCH body.

It should contain:

```json
{
  "environmentId": "00000000-0000-0000-0000-000000000000",
  "currencyAllocations": [
    {
      "currencyType": "MCSMessages",
      "allocated": 0,
      "enforcementRules": [
        {
          "ruleType": "TenantPool",
          "enabled": false
        }
      ]
    }
  ]
}
```

If the request is correct, remove `-WhatIf`:

```powershell
.\Set-PowerPlatformSingleEnvironmentAllocation.ps1 `
    -EnvironmentId "00000000-0000-0000-0000-000000000000" `
    -TenantId "11111111-1111-1111-1111-111111111111" `
    -ClientId "22222222-2222-2222-2222-222222222222" `
    -ClientSecret $clientSecret `
    -CurrencyType MCSMessages `
    -Allocated 0 `
    -EnforcementRuleType TenantPool `
    -EnforcementRuleEnabled $false
```

# Update multiple environments using CSV

Use `Set-PowerPlatformEnvironmentAllocationsFromCsv.ps1` to update multiple environments.

## CSV format

The CSV must contain the following columns:

```csv
EnvironmentId,Allocated,EnforcementRuleType,EnforcementRuleEnabled
```

Example:

```csv
EnvironmentId,Allocated,EnforcementRuleType,EnforcementRuleEnabled
00000000-0000-0000-0000-000000000000,0,TenantPool,false
11111111-1111-1111-1111-111111111111,500,TenantPool,true
22222222-2222-2222-2222-222222222222,1000,Alert,true
```

The `CurrencyType` command-line parameter applies to every row in the CSV.

## Preview the CSV updates

```powershell
$clientSecret = Read-Host "Enter client secret" -AsSecureString

.\Set-PowerPlatformEnvironmentAllocationsFromCsv.ps1 `
    -CsvPath ".\examples\allocations.example.csv" `
    -TenantId "11111111-1111-1111-1111-111111111111" `
    -ClientId "22222222-2222-2222-2222-222222222222" `
    -ClientSecret $clientSecret `
    -CurrencyType MCSMessages `
    -WhatIf
```

PowerShell displays one `What if` message for each environment.

## Apply the CSV updates

Remove `-WhatIf`:

```powershell
.\Set-PowerPlatformEnvironmentAllocationsFromCsv.ps1 `
    -CsvPath ".\examples\allocations.example.csv" `
    -TenantId "11111111-1111-1111-1111-111111111111" `
    -ClientId "22222222-2222-2222-2222-222222222222" `
    -ClientSecret $clientSecret `
    -CurrencyType MCSMessages
```

The script:

1. Imports the CSV.
2. Authenticates once.
3. Validates each row.
4. Loops through the rows.
5. Sends one PATCH request per environment.

# Enforcement rules

Supported enforcement rule values include:

```text
Alert
PayGo
TenantPool
Deny
```

The `TenantPool` rule controls whether an environment can draw from the tenant's available capacity.

| Configuration | Behavior |
|---|---|
| `TenantPool`, `true` | Allows the environment to draw from available tenant capacity. |
| `TenantPool`, `false` | Prevents the environment from drawing from available tenant capacity. |

To prevent an environment from consuming tenant-pool capacity:

```text
Allocated = 0
EnforcementRuleType = TenantPool
EnforcementRuleEnabled = false
```

# Repository structure

Recommended repository structure:

```text
PowerPlatform-Credit-Allocation-Scripts/
├── README.md
├── LICENSE
├── Set-PowerPlatformSingleEnvironmentAllocation.ps1
├── Set-PowerPlatformEnvironmentAllocationsFromCsv.ps1
└── examples/
    └── allocations.example.csv
```

# Security recommendations

- Never commit client secrets or access tokens.
- Use a dedicated app registration.
- Store production secrets in Azure Key Vault or another approved secret manager.
- Use short secret-expiration periods.
- Rotate secrets regularly.
- Use fake tenant, client, and environment IDs in public examples.
- Run with `-WhatIf` before every production update.
- Review CSV files before execution.
- Do not commit CSV files containing real environment IDs unless repository access is appropriately restricted.

# Troubleshooting

## `403 Forbidden`

Confirm that:

- The client secret is valid and has not expired.
- Admin consent was granted.
- The application belongs to the correct tenant.
- The service principal was registered using `New-PowerAppManagementApp`.
- The application is authorized to update licensing allocations.

## `UnknownError`

Confirm that:

- The currency type already exists for the environment.
- The allocation is `0` or greater than or equal to `500`.
- The tenant has sufficient capacity.
- No enforcement rule has an empty `ruleType`.
- `EnforcementRuleEnabled` is `true` or `false`.

## Invalid CSV values

Each CSV row must contain:

- A valid environment ID.
- An allocation of `0` or at least `500`.
- A supported enforcement rule type.
- `true` or `false` for `EnforcementRuleEnabled`.

## Power Platform modules cannot be loaded

If Windows PowerShell reports that script execution is disabled:

```powershell
Set-ExecutionPolicy `
    -Scope Process `
    -ExecutionPolicy Bypass `
    -Force
```

If a module is missing:

```powershell
Install-Module `
    -Name Microsoft.PowerApps.PowerShell `
    -Scope CurrentUser `
    -Force `
    -AllowClobber

Install-Module `
    -Name Microsoft.PowerApps.Administration.PowerShell `
    -Scope CurrentUser `
    -Force `
    -AllowClobber
```

# Disclaimer

These scripts modify Power Platform credit allocations and enforcement behavior.

Test them in a nonproduction environment and review every `-WhatIf` result before applying changes to production.

The scripts are provided without warranty. You are responsible for validating:

- Capacity availability.
- Licensing requirements.
- Security configuration.
- API permissions.
- Operational impact.
- Compliance with your organization's policies.
