param(
    $resourceGroupName="resourceGroupName",
    $subscriptionId="99999-9999-9999-9999-9999999",
    $dedicatedCapacityName="fabricCapacityname"
)
$ErrorActionPreference="Stop"

$mod = (Get-Module Az.Accounts -ListAvailable)
if( $null -eq $mod )
{
    Install-Module -Name Az.Accounts -AllowClobber -Force
}
else
{
    Write-Verbose "Az.Accounts Version=$($mod.Version.Major)"
}
Import-Module -Name Az.Accounts 

if( $host.Name -like "Visual Studio*" )
{
    $null = Connect-AzAccount
}
else
{
    $null = Connect-AzAccount -Identity
}
$token = (Get-AzAccessToken).Token
$header=@{}
$header.Add("Authorization","Bearer $token")

$uri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Fabric/capacities/$($dedicatedCapacityName)?api-version=2022-07-01-preview"

Write-Verbose $uri
$response = Invoke-RestMethod -uri $uri -Method Get -Headers $header -UseBasicParsing

Write-Output $("Status is " + $response.properties.state)

if( "Active" -eq $response.properties.state )
{
    Write-Output "Pausing"
    $uri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Fabric/capacities/$dedicatedCapacityName/suspend?api-version=2022-07-01-preview"
    $response = Invoke-WebRequest -uri $uri -Method Post -Headers $header -UseBasicParsing
}
