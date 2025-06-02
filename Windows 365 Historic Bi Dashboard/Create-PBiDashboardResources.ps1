#Requires -modules Az.Accounts,Az.ManagedServiceIdentity,Az.OperationalInsights,Az.Automation,Az.Monitor,Az.Resources,Microsoft.Graph.Applications,Microsoft.Graph.Authentication

# =====================
# Variables (replace placeholders before use)
# =====================

$tenantId = "<YOUR_TENANT_ID_HERE>" # Replace with your Azure Tenant ID
$resourceGroupName = "<RESOURCE_GROUP_NAME>" # Replace with your Resource Group name
$location = "East US" # Azure region
$workspaceName = "W365CustomReporting"
$dataCollectionRuleName = "DCR-W365-CustomReporting"
$automationAccountName = "AzAut-W365-CustomReporting"
$managedIdentityName = "MI_W365-CustomReporting"
$customTableName = "W365_CloudPCs_CL"
$streamDeclarationName = "Custom-CloudPCsRAW"
$OutputStreamName = "Custom-W365_CloudPCs_CL"
$appRegistrationName = "W365_CustomReporting_App"
$RunbookName = "CloudPCDataCollection"

# =====================
# Authenticate to Azure
# =====================
try {
    Connect-AzAccount -ErrorAction Stop
    Connect-MgGraph -Scopes "Application.ReadWrite.All,AppRoleAssignment.ReadWrite.All" -ErrorAction Stop
    Write-Host "Successfully authenticated to Azure and Microsoft Graph."
} catch {
    Write-Error "Failed to authenticate to Azure or Microsoft Graph: $_"
    exit 1
}

# =====================
# 1. Create Log Analytics Workspace
# =====================
try {
    $workspace = New-AzOperationalInsightsWorkspace -ResourceGroupName $resourceGroupName `
        -Name $workspaceName `
        -Location $location `
        -Sku "PerGB2018" -ErrorAction Stop
    Write-Host "Log Analytics Workspace created: $($workspace.Name)"
} catch {
    Write-Error "Failed to create Log Analytics Workspace: $_"
    exit 1
}

# =====================
# 2. Create Custom Table in Log Analytics
# =====================
$tableParams = @"
{
    'properties': {
        'schema': {
            'name': '$customTableName',
            'columns': [
                { 'name': 'TimeGenerated', 'type': 'DateTime' },
                { 'name': 'DisplayName', 'type': 'String' },
                { 'name': 'Id', 'type': 'String' },
                { 'name': 'UserPrincipalName', 'type': 'String' },
                { 'name': 'ServicePlanName', 'type': 'String' },
                { 'name': 'ServicePlanId', 'type': 'String' },
                { 'name': 'ProvisioningPolicyName', 'type': 'String' },
                { 'name': 'ProvisioningType', 'type': 'String' },
                { 'name': 'Department', 'type': 'String' }
            ]
        }
    }
}
"@

try {
    Invoke-AzRestMethod -Path "$($workspace.ResourceId)/tables/$($customTableName)?api-version=2021-12-01-preview" `
        -Method PUT `
        -Payload $tableParams -ErrorAction Stop
    Write-Host "Custom table created in Log Analytics Workspace."
} catch {
    Write-Error "Failed to create custom table: $_"
    exit 1
}

# =====================
# 3. Create Data Collection Endpoint (DCE) and Data Collection Rule (DCR)
# =====================
try {
    $dce = New-AzDataCollectionEndpoint -ResourceGroupName $resourceGroupName `
        -Name "$($dataCollectionRuleName)-DCE" `
        -Location $location `
        -NetworkAclsPublicNetworkAccess Enabled -ErrorAction Stop
    Write-Host "Data Collection Endpoint created."
} catch {
    Write-Error "Failed to create Data Collection Endpoint: $_"
    exit 1
}

$jsonTemplate = @"
{
    'location': '$location',
    'properties': {
    'streamDeclarations': {
        '$streamDeclarationName': {
        'columns': [
            { 'name': 'TimeGenerated', 'type': 'datetime' },
            { 'name': 'DisplayName', 'type': 'string' },
            { 'name': 'Id', 'type': 'string' },
            { 'name': 'UserPrincipalName', 'type': 'string' },
            { 'name': 'ServicePlanName', 'type': 'string' },
            { 'name': 'ServicePlanId', 'type': 'string' },
            { 'name': 'ProvisioningPolicyName', 'type': 'string' },
            { 'name': 'ProvisioningType', 'type': 'string' },
            { 'name': 'Department', 'type': 'string' }
        ]
        }
    },
    'dataCollectionEndpointId': '$($dce.id)',
    'destinations': {
        'logAnalytics': [
        {
            'workspaceResourceId': '$($workspace.ResourceId)',
            'name': '$workspaceName',
        }
        ]
    },
    'dataFlows': [
        {
        'streams': ['$streamDeclarationName'],
        'destinations': ['$WorkspaceName'],
        'transformKql': 'source | project TimeGenerated, DisplayName, Id, UserPrincipalName, ServicePlanName, ServicePlanId, ProvisioningPolicyName, ProvisioningType, Department',
        'outputStream': '$OutputStreamName'
        }
    ]
    }
}
"@

try {
    $dcr = New-AzDataCollectionRule -Name $dataCollectionRuleName `
        -ResourceGroupName $resourceGroupName `
        -JsonString $jsonTemplate -ErrorAction Stop
    Write-Host "Data Collection Rule created."
} catch {
    Write-Error "Failed to create Data Collection Rule: $_"
    exit 1
}

# =====================
# Get Immutable ID and Log Ingestion URL
# =====================
try {
    $dcrImmutableId = $dcr.ImmutableId
    $logIngestionUrl = $dce.LogIngestionEndpoint
    Write-Output "DCR Immutable ID: $dcrImmutableId"
    Write-Output "Log Ingestion URL: $logIngestionUrl"
} catch {
    Write-Error "Failed to retrieve DCR Immutable ID or Log Ingestion URL: $_"
    exit 1
}

# =====================
# 4. Create User-Assigned Managed Identity
# =====================
try {
    $managedIdentity = New-AzUserAssignedIdentity -ResourceGroupName $resourceGroupName `
        -Name $managedIdentityName `
        -Location $location -ErrorAction Stop
    $managedIdentityClientId = $managedIdentity.ClientId
    $managedIdentityId = $managedIdentity.Id
    $managedIdentityPrincipalId = $managedIdentity.PrincipalId
    Write-Host "Managed Identity created."
} catch {
    Write-Error "Failed to create Managed Identity: $_"
    exit 1
}

# =====================
# 5. Create Azure Automation Account and assign Managed Identity
# =====================
try {
    $automationAccount = New-AzAutomationAccount -ResourceGroupName $resourceGroupName `
        -Name $automationAccountName `
        -Location $location `
        -AssignUserIdentity $managedIdentityId -ErrorAction Stop
    Write-Host "Automation Account created."
} catch {
    Write-Error "Failed to create Automation Account: $_"
    exit 1
}

# Assign Automation Runbook Operator role to the managed identity on the Automation Account
try {
    New-AzRoleAssignment `
        -ObjectId $managedIdentityPrincipalId `
        -RoleDefinitionName "Automation Runbook Operator" `
        -ResourceGroupName $resourceGroupName -ErrorAction Stop
    Write-Host "Role assignment (Automation Runbook Operator) completed."
} catch {
    Write-Error "Failed to assign Automation Runbook Operator role: $_"
    exit 1
}

# =====================
# 6. Assign permissions to Managed Identity (Graph API permissions must be assigned via Entra ID App Registration)
# =====================
# Create a new app registration for the managed identity, assign API permissions (CloudPC.Read.All,Directory.Read.All), and grant admin consent

$requiredResourceAccess = @(
    @{
        ResourceAppId = "00000003-0000-0000-c000-000000000000" # Microsoft Graph
        ResourceAccess = @(
            @{ Id = "a9e09520-8ed4-4cde-838e-4fdea192c227"; Type = "Role" }, # CloudPC.Read.All
            @{ Id = "7ab1d382-f21e-4acd-a863-ba3e13f7da61"; Type = "Role" } # Directory.Read.All
        )
    }
)

$federatedIdentityCredential = @{
    name = "$managedIdentityName"
    issuer = "https://login.microsoftonline.com/$($managedIdentity.TenantId)/v2.0"
    subject = "$($managedIdentity.PrincipalId)"
    audiences = @("api://AzureADTokenExchange")
}

try {
    $app = New-MgApplication -DisplayName $appRegistrationName `
        -SignInAudience "AzureADMyOrg" `
        -RequiredResourceAccess $requiredResourceAccess -ErrorAction Stop
    Write-Host "App registration created."
} catch {
    Write-Error "Failed to create app registration: $_"
    exit 1
}

try {
    $sp = New-MgServicePrincipal -AppId $app.AppId -ErrorAction Stop
    $graphSp = Get-MgServicePrincipal -Filter "appId eq '00000003-0000-0000-c000-000000000000'" -ErrorAction Stop
    ForEach ($appRoleId in $($requiredResourceAccess.resourceAccess.id)) {
        $Assignment = @{
            PrincipalId = $sp.id
            ResourceId  = $graphSp.id
            AppRoleId   = $appRoleId
        }
        New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $assignment.PrincipalId -BodyParameter $Assignment -ErrorAction Stop
    }
    Write-Host "Service principal and role assignments created."
} catch {
    Write-Error "Failed to create service principal or assign roles: $_"
    exit 1
}

try {
    $managedIdentityFederatedIdentity = New-MgApplicationFederatedIdentityCredential -ApplicationId $app.Id `
        -BodyParameter $federatedIdentityCredential -ErrorAction Stop
    Write-Host "Federated identity credential added to app registration."
} catch {
    Write-Error "Failed to add federated identity credential: $_"
    exit 1
}

try {
    $Assignment = New-AzRoleAssignment -ObjectId $managedIdentity.PrincipalId `
        -RoleDefinitionName "Monitoring Metrics Publisher" `
        -Scope $dcr.Id -ErrorAction Stop
    Write-Host "Monitoring Metrics Publisher role assigned to managed identity."
} catch {
    Write-Error "Failed to assign Monitoring Metrics Publisher role: $_"
    exit 1
}

# =====================
# 7. Create Azure Automation Runbook
# =====================
$runbookContent = @"
#region Step 1 - Set variables
# The client id of the user assigned identity we created
`$UAIClientId = "$($managedIdentityClientId)"

# The Principal id of the user assigned identity we created
`$UAIPrincipalId = "$($managedIdentityPrincipalId)"
 
# The client id of the app registration we created
`$appClientId = "$($app.AppId)"

# Tenant id of tenant B
`$TenantId = "$($tenantId)"
#endregion

Disable-AzContextAutosave -Scope Process
Connect-AzAccount -Identity -AccountId "`$UAIPrincipalId"
 
#region Step 2 - Authenticate as the user assigned identity
#This is designed to run in Azure Automation; `$env:IDENTITY_header and `$env:IDENTITY_ENDPOINT are set by the Azure Automation service.
try {
    `$accessToken = Invoke-RestMethod `$env:IDENTITY_ENDPOINT -Method 'POST' -Headers @{
        'Metadata'          = 'true'
        'X-IDENTITY-HEADER' = `$env:IDENTITY_HEADER
    } -ContentType 'application/x-www-form-urlencoded' -Body @{
        'resource'  = 'api://AzureADTokenExchange'
        'client_id' = `$UAIClientId
    }
    if(-not `$accessToken.access_token) {
        throw "Failed to acquire access token"
    } else {
        Write-Output "Successfully acquired access token for user assigned identity"
    }
} catch {
    throw "Error acquiring access token: `$_"
}
#endregion
 
#region Step 3 - Exchange the access token from step 2 for a token in the target tenant using the app registration
try {
    `$graphBearerToken = Invoke-RestMethod "https://login.microsoftonline.com/`$TenantId/oauth2/v2.0/token" -Method 'POST' -Body @{
        client_id             = `$appClientId
        scope                 = 'https://graph.microsoft.com/.default'
        grant_type            = "client_credentials"
        client_assertion_type = "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"
        client_assertion      = `$accessToken.access_token
    }
    if(-not `$graphBearerToken.access_token) {
        throw "Failed to acquire Bearer token for Microsoft Graph API"
    } else {
        Write-Output "Successfully acquired Bearer token for Microsoft Graph API"
    }
} catch {
    throw "Error acquiring Microsoft Graph API token: `$_"
}
#endregion

# Get Cloud PCs from Graph
try {
    `$payload = @()
    `$cloudPCs = Invoke-RestMethod -Uri 'https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs?`$select=id,displayName,userPrincipalName,servicePlanName,servicePlanId,ProvisioningPolicyName,ProvisioningType' -Headers @{Authorization="Bearer `$(`$graphBearerToken.access_token)"}
    `$CloudPCArray= @()
    `$CloudPCs.value | ForEach-Object {
        `$CloudPCArray += [PSCustomObject]@{
            Id = `$_.id
            DisplayName = `$_.displayName
            UserPrincipalName = `$_.userPrincipalName
            ServicePlanName = `$_.servicePlanName
            ServicePlanId = `$_.servicePlanId
            ProvisioningPolicyName = `$_.ProvisioningPolicyName
            ProvisioningType = `$_.ProvisioningType
        }
    }
    # Prepare payload
    foreach (`$CloudPC in `$CloudPCArray) {
        If(`$null -ne `$CloudPC.UserPrincipalName){
            try {
                `$UPN = `$CloudPc.userPrincipalName
                `$URI = "https://graph.microsoft.com/v1.0/users/`$UPN" + '?`$select=userPrincipalName,department'
                `$userObj = Invoke-RestMethod -Method GET -Uri `$URI -Headers @{Authorization="Bearer `$(`$graphBearerToken.access_token)"}
                `$userDepartment = `$UserObj.Department
            } catch {
                `$userDepartment = "[User department not found]"
            }
        } else {
            `$userDepartment = "[Shared - Not Applicable]"
        }
        `$CloudPC | Add-Member -MemberType NoteProperty -Name Department -Value `$userDepartment
        `$CloudPC | Add-Member -MemberType NoteProperty -Name TimeGenerated -Value (Get-Date).ToUniversalTime().ToString("o")
        `$payload += `$CloudPC
    }
} catch {
    throw "Error retrieving Cloud PCs or user department: `$_"
}

# Send data to Log Analytics
try {
    `$ingestionUri = '$logIngestionUrl/dataCollectionRules/$dcrImmutableId/streams/$streamDeclarationName`?api-version=2023-01-01'
    `$ingestionToken = (Get-AzAccessToken -ResourceUrl 'https://monitor.azure.com//.default').Token
    Invoke-RestMethod -Uri `$ingestionUri -Method Post -Headers @{Authorization="Bearer `$ingestionToken"} -Body (`$payload | ConvertTo-Json -Depth 10) -ContentType 'application/json'
    Write-Output "Data sent to Log Analytics."
} catch {
    throw "Error sending data to Log Analytics: `$_"
}
"@

$tempfile = [System.IO.Path]::GetTempFileName() -replace '\.tmp$', '.ps1'
Set-Content -Path $tempfile -Value $runbookContent

try {
    Import-AzAutomationRunbook -ResourceGroupName $resourceGroupName `
        -AutomationAccountName $automationAccountName `
        -Name "$($runbookName)" `
        -Path $tempfile `
        -Type PowerShell72 `
        -Force -ErrorAction Stop
    Write-Host "Runbook imported successfully."
} catch {
    Write-Error "Failed to import runbook: $_"
    exit 1
}

remove-item $tempFile

Write-Host "Setup complete. Runbook created and ready to execute."


