<#
.SYNOPSIS
    One-time bootstrap for arias-sh: Terraform state storage + GitHub Actions OIDC identity.
    Safe to re-run. Requires: az login, gh auth login, PowerShell 7.4+.
#>
param(
    [string]$Location       = 'eastus2',
    [string]$GitHubRepo     = 'jbug187/arias-sh',
    [string]$StateRg        = 'rg-arias-tfstate',
    [string]$ProjectRg      = 'rg-arias-sh',
    [string]$StateAccount   = 'ariasshtfstate',   # globally unique, 3-24 lowercase letters/digits
    [string]$StateContainer = 'tfstate',
    [string]$IdentityName   = 'id-arias-github'
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true   # stop on any failed az/gh call

$sub   = az account show | ConvertFrom-Json
$subId = "/subscriptions/$($sub.id)"
Write-Host "Subscription: $($sub.name)" -ForegroundColor Cyan

function Grant($principalId, $principalType, $role, $scope) {
    $existing = az role assignment list --assignee $principalId --role $role --scope $scope --query '[0].id' -o tsv
    if (-not $existing) {
        az role assignment create --assignee-object-id $principalId --assignee-principal-type $principalType `
            --role $role --scope $scope -o none
    }
    Write-Host "  $role -> $($scope.Split('/')[-1])"
}

# 1. Resource groups: one for state (long-lived), one for the site (Terraform-managed contents)
Write-Host 'Resource groups...' -ForegroundColor Cyan
az group create -n $StateRg   -l $Location -o none
az group create -n $ProjectRg -l $Location -o none

# 2. State storage: no public blobs, no shared keys (Entra ID auth only), versioning + soft delete
Write-Host 'State storage account...' -ForegroundColor Cyan
if (-not (az storage account list -g $StateRg --query "[?name=='$StateAccount'].id" -o tsv)) {
    $check = az storage account check-name -n $StateAccount | ConvertFrom-Json
    if (-not $check.nameAvailable) { throw "Storage account name '$StateAccount' is taken. Re-run with -StateAccount <another name>." }
}
az storage account create -n $StateAccount -g $StateRg -l $Location `
    --sku Standard_LRS --kind StorageV2 --min-tls-version TLS1_2 --https-only true `
    --allow-blob-public-access false --allow-shared-key-access false -o none

az storage account blob-service-properties update --account-name $StateAccount -g $StateRg `
    --enable-versioning true `
    --enable-delete-retention true --delete-retention-days 30 `
    --enable-container-delete-retention true --container-delete-retention-days 30 -o none

if (-not (az storage container-rm list --storage-account $StateAccount -g $StateRg --query "[?name=='$StateContainer'].name" -o tsv)) {
    az storage container-rm create --storage-account $StateAccount -g $StateRg -n $StateContainer -o none
}

# 3. Managed identity for GitHub Actions, trusted only for this repo's main branch and PRs
Write-Host 'GitHub Actions identity...' -ForegroundColor Cyan
$id = az identity create -n $IdentityName -g $StateRg -l $Location | ConvertFrom-Json

@{
    'github-main' = "repo:${GitHubRepo}:ref:refs/heads/main"
    'github-pr'   = "repo:${GitHubRepo}:pull_request"
}.GetEnumerator() | ForEach-Object {
    az identity federated-credential create --name $_.Key --identity-name $IdentityName -g $StateRg `
        --issuer 'https://token.actions.githubusercontent.com' --subject $_.Value `
        --audiences 'api://AzureADTokenExchange' -o none
    Write-Host "  trusts $($_.Value)"
}

# 4. Least-privilege roles
Write-Host 'Role assignments...' -ForegroundColor Cyan
$projectScope   = "$subId/resourceGroups/$ProjectRg"
$containerScope = "$subId/resourceGroups/$StateRg/providers/Microsoft.Storage/storageAccounts/$StateAccount/blobServices/default/containers/$StateContainer"
$me             = az ad signed-in-user show --query id -o tsv

Grant $id.principalId 'ServicePrincipal' 'Contributor'                              $projectScope
Grant $id.principalId 'ServicePrincipal' 'Role Based Access Control Administrator'  $projectScope
Grant $id.principalId 'ServicePrincipal' 'Storage Blob Data Contributor'            $containerScope
Grant $me             'User'             'Storage Blob Data Contributor'            $containerScope

# 5. Delete lock on the state resource group (added last so setup can still change things)
Write-Host 'Delete lock...' -ForegroundColor Cyan
az lock create -n 'no-delete' --lock-type CanNotDelete -g $StateRg -o none

# 6. Non-secret identifiers as GitHub Actions variables
Write-Host 'GitHub Actions variables...' -ForegroundColor Cyan
@{
    AZURE_CLIENT_ID       = $id.clientId
    AZURE_TENANT_ID       = $sub.tenantId
    AZURE_SUBSCRIPTION_ID = $sub.id
    TF_STATE_RG           = $StateRg
    TF_STATE_ACCOUNT      = $StateAccount
    TF_STATE_CONTAINER    = $StateContainer
}.GetEnumerator() | ForEach-Object {
    gh variable set $_.Key --body $_.Value --repo $GitHubRepo
}

Write-Host "`nBootstrap complete. Role assignments can take a few minutes to take effect." -ForegroundColor Green