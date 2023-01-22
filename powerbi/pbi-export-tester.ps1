[CmdletBinding()]
param()
$ErrorActionPreference="Stop"

$configPath = (Join-Path $PSScriptRoot "pbi-export-tester.json")

if( -not (Test-Path $configPath) )
{
    Write-Output "Unable to locate configuration file $configPath"
    throw "Configuration path invalid"
}
$config = (Get-Content $configPath | ConvertFrom-Json -Depth 8)

#Load PowerShell modules
$mod = (Get-Module MicrosoftPowerBIMgmt -ListAvailable)
if( $null -eq $mod )
{
    Install-Module MicrosoftPowerBIMgmt -AllowClobber -Force
}
else
{
    Write-Verbose "PBI Version=$($mod.Version.Major)"
}
Import-Module -Name MicrosoftPowerBIMgmt 

# If running multiple times we may not want to get the header over and over
if( $headers )
{
    $rh = Read-Host "Do you want to reset the header?"
    if( "y" -eq $rh )
    {
        $headers.Clear()
    }
}
else
{
    $headers=@{}
}

if( 0 -eq $headers.Count )
{
    Connect-PowerBIServiceAccount #-Tenant $TenantId 
    $headers = Get-PowerBIAccessToken
    $headers.Add("Content-type", "application/json")
}

#Action=Report,Export,Status
function Invoke-PBIExportRequest()
{
    [CmdletBinding()]
    param(
        $export,
        [ValidateSet("Report", "Export","Status","ToFile")]
        $action="Report"
    )
    $uri = "https://api.powerbi.com/v1.0/myorg/groups/{0}/reports/{1}{2}"
    $uri = $uri -f $export.workspaceId,$export.reportId,"{0}"

    $extUri=switch($action) 
    { 
        "Export"{"/ExportTo"} 
        "Status"{"/exports/$($export.exportId)"} 
        "ToFile"{"/exports/$($export.exportId)/file"}
        default{""} 
    }
    # $method=switch ($action) { "Export"{"Post"} default{"Get"} }

    $uri = $uri -f $extUri
    try
    {
        if( $action -eq "Export" )
        {
            $response = Invoke-RestMethod -Headers $headers -Uri $uri -Body $export.body -Method "Post"
            $export.exportId=$response.id
        }
        elseif( $action -eq "ToFile" )
        {
            $fileName = "{0}{1}" -f $export.outputFile, $export.outputFileExt
            $fileName = Join-Path $PSScriptRoot $fileName

            Write-Host "Saving file $fileName"

            Invoke-WebRequest -Uri $uri -OutFile $fileName -Headers $headers              
        }
        else
        {
            $response = Invoke-RestMethod -Headers $headers -Uri $uri -Method "Get"
            if( $action -eq "Report" )
            {
                $export.reportName=$response.name;
                $export.reportType=$response.reportType;
            }
            elseif( $action -eq "Status" )
            {
                $export.outputFileExt=$response.resourceFileExtension
                $export.status = $response.status
                $export.percentComplete = $response.percentComplete
                if( $export.percentComplete -eq 100 )
                {
                    $export.endDate=Get-Date
                }                
                if( $response.error )
                {
                    $export.errorMessage=$response.error.message
                }                
            }
        }
    }
    catch
    {
        $ex = $_.Exception    
        if( $_.ErrorDetails )
        {
            $export.errorMessage=$_.ErrorDetails.Message
        }
        else
        {
            $export.errorMessage=$ex.Message
        }
        $export.errorMessage+=" (action=$action)"
        $export.status="Failed"
    }
}

$exports=@()
foreach( $report in ($config.reports.Where({$_.enabled})) )
{
    if( -not $report.workspaceId )
    {
        Write-Host "Run the following to get the workspace:"
        Write-Host "Get-PowerBIWorkspace -All | where {(`$_.Name -like `"*Sales*`")}"
        throw "Missing Workspace ID"
    }
    
    if( -not $report.reportId )
    {
        Write-Host "Run the following to get the report:"
        Write-Host "Get-PowerBIReport -WorkspaceId $($report.workspaceId)"
        throw "Missing Report ID"
    }
    
    $export= [PSCustomObject]@{
        reportId=$report.reportId;
        workspaceId=$report.workspaceId;
        reportName="";
        reportType="";
        exportId="";
        status="Ready";
        percentComplete=0;
        outputFile=$report.outputFile;
        outputFileExt="";
        errorMessage="";
        startDate=$null;
        endDate=$null;
        totalSeconds=$null;
        body=($report.body|ConvertTo-json -Depth 4)
    }
    Invoke-PBIExportRequest -export $export -action "Report"

    Write-Output "Adding report: $($export.reportName) ($($export.outputFile)) $($export.reportType)"
    
    $exports+=$export

    #Add all instances of the export
    if( $report.instances -gt 1 )
    {
        $i = 2
        while($i -lt $report.instances)
        {
            $copy = $export.psobject.Copy()
            $copy.outputFile = $export.outputFile+"_"+$i
            Write-Host "...Copy $($copy.outputFile)"
            $exports+=$copy
            $i++
        }
    }
}    

#Execute the exports for each report
foreach($export in ($exports.Where({"Ready" -contains $_.Status})))
{
    $export.status="Running"
    $export.startDate=Get-Date
    Invoke-PBIExportRequest -export $export -action "Export"
}

$running=$true
while($running)
{
    foreach($export in ($exports.Where({"Running","NotStarted" -contains $_.Status})))
    {
        Invoke-PBIExportRequest -export $export -action "Status"
    
        Write-Host "$($export.reportName) ($($export.outputFile)) $($export.status) $($export.percentComplete)%"
    }
    $running = $exports.Where({"Running","NotStarted" -contains $_.Status})
    if( $running )
    {
        Write-Output "Sleeping $($config.wait) seconds..."
        Start-Sleep $config.wait
    }
}

Write-Host "Process Complete..."
foreach( $export in $exports )
{
    Write-Host "$($export.reportName) ($($export.outputFile))" -NoNewline
    if( $export.endDate )
    {
        $ts = New-TimeSpan -Start $export.startDate -End $export.endDate
        $export.totalSeconds = $ts.TotalSeconds
        Write-Host "`t$($ts.TotalSeconds)"
    }
    else
    {
        Write-Host "`t$($export.status): $($export.errorMessage)" -ForegroundColor Red
    }
}

if( $config.exportToDisk )
{
    Write-Host "Exporting..."

    foreach($export in $exports)
    {
        if( "Failed" -notcontains $export.status )
        {
            Invoke-PBIExportRequest -export $export -action "ToFile"
        }
    }
}
$mo = ($exports|where status -ne "Failed"|select -expandproperty totalSeconds|Measure-Object -average -Minimum -Maximum)
Write-Host $("Count:{0}`tAvg:{1}`tMin:{2}`tMax:{3}" -f $mo.Count,$mo.Average,$mo.Minimum,$mo.Maximum)