$ErrorActionPreference="Stop"
$items=@()

$cfg=@{}
Get-Content (Join-Path $PSScriptRoot ".env")|%{$x,$y=$_.split("=");$cfg[$x]=$y}

$tenantId = $cfg["AZURE_TENANT"]

Connect-AzAccount -TenantId $tenantId

$token = (Get-AzAccessToken -ResourceUrl https://management.azure.com).Token

$headers = @{"authorization"="Bearer $token"; "Accept"="application/json"}

$subs = Invoke-RestMethod -Uri https://management.azure.com/subscriptions?api-version=2022-12-01 -Headers $headers -Method GET

foreach($sub in $subs.value)
{
    Write-Host $sub.subscriptionId
    $subId = $sub.subscriptionId


    $quota=@{}
    $locations=@('australiaeast','canadaeast','eastus','eastus2','francecentral','japaneast','northcentralus','southcentralus','swedencentral','switzerlandnorth','uksouth','westeurope')
    foreach($location in $locations)
    {
        if( $quota -contains $location)
        {
            continue
        }
        else 
        {
            $quota[$location]=@{}
            $usages = Invoke-RestMethod "https://management.azure.com/subscriptions/$subId/providers/Microsoft.CognitiveServices/locations/$location/usages?api-version=2023-05-01" -Headers $headers -Method Get
            foreach($usage in $usages.value)
            {
                if($usage.name.value.startswith("OpenAI.Standard."))
                {
                    $quota_name = $usage.name.value.replace("OpenAI.Standard.", "").ToLower()
                    $quota.$location.$quota_name= $usage.limit
                }
            }
        }
    }

    # Get the resource groups
    $rgs = Invoke-RestMethod -Uri "https://management.azure.com/subscriptions/$subId/resourceGroups?api-version=2022-12-01" -Headers $headers -Method GET
    foreach($rg in $rgs.value)
    {
        $resourceGroupName = $rg.name
        $location = $rg.location

        $accounts = Invoke-RestMethod -Uri "https://management.azure.com/subscriptions/$subId/resourceGroups/$resourceGroupName/providers/Microsoft.CognitiveServices/accounts?api-version=2023-05-01" -Headers $headers -Method GET
        foreach($acct in $accounts.value)
        {
            $accountName = $acct.name
            $deployments = Invoke-RestMethod -Uri "https://management.azure.com/subscriptions/$subId/resourceGroups/$resourceGroupName/providers/Microsoft.CognitiveServices/accounts/$accountName/deployments?api-version=2023-05-01" -Headers $headers -Method GET
            foreach($deploy in $deployments.value)
            {
                $deploy.Name
                $model=$deploy.properties.model.name
                $tpm=($deploy.properties.rateLimits|?{$_.key -eq "token"}).count
                $qt=$quota[$location][$model]*1000
                $items+= New-Object PSObject -Property @{
                    subscriptionId=$subId
                    resourceGroupName=$resourceGroupName
                    accountName=$accountName
                    deploymentName=$deploy.name
                    model=$model
                    tpm=$tpm
                    quota=$qt
                    location=$location
                }
            }
        }
    }
}
