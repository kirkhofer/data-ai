<#
    Automation account must have "Contributor" on the Azure resource
#>
param(
    $resourceGroupName="rg-dai-dev-usc",
    $subscriptionId="cd60139f-77b6-4946-8ff6-7c2135d571fa",
    $dedicatedCapacityName="pbiedaidevusw301"
)
$ErrorActionPreference="Stop"

$null = Connect-AzAccount -Identity
$token = (Get-AzAccessToken).Token
$header=@{}
$header.Add("Authorization","Bearer $token")

$uri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.PowerBIDedicated/capacities/$($dedicatedCapacityName)?api-version=2021-01-01"

Write-Verbose $uri
$response = Invoke-RestMethod -uri $uri -Method Get -Headers $header -UseBasicParsing

Write-Output $("Status is " + $response.properties.state)

if( "Succeeded" -eq $response.properties.state )
{
    Write-Output "Pausing"
    $uri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.PowerBIDedicated/capacities/$dedicatedCapacityName/suspend?api-version=2021-01-01"
    $response = Invoke-WebRequest -uri $uri -Method Post -Headers $header -UseBasicParsing
}
