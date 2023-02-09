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

if( (-not $runTime) -or ($runTime -and (Get-Date) -gt $runTime) )
{
    #AlexW, LarryS
    $rt = Read-Host "How many users do you want to run?"
    $i=0
    $tokens=@()
    while( $i -lt $rt )
    {
        $login = Login-PowerBIServiceAccount
        $tokens+=[PSCustomObject]@{
            userName = $login.UserName
            token = (Get-PowerBIAccessToken -AsString | % {$_.replace("Bearer ","").Trim()})
        }
        $i++
    }
    # Token expires in 60 minutes
    $runTime = (Get-Date).AddMinutes(60)
}

$reports=@()
# foreach( $item in ($config.reports.Where({$_.enabled})) )
foreach( $item in ($config.reports.Where({$_.body.paginatedReportConfiguration})) )
{
    $report = New-Object PSObject -Property @{
        workspaceId = $item.workspaceId
        reportId = $item.reportId
        instances = $item.instances
        embedUrl = (Get-PowerBIReport -Id $item.reportId -WorkspaceId $item.workspaceId | Select -ExpandProperty EmbedUrl)
        reportType = ($item.body.paginatedReportConfiguration ? "paginated" : "report")
        parameters=$null
    }
    if( $report.reportType -eq "paginated" )
    {
        $report.parameters = $item.body.paginatedReportConfiguration.parameterValues
        $reports+=$report
    }
    else
    {
        #TODO: Add support for crazy filter syntax of reports
        Write-Host "Not supported"
        #$report.parameters = $item.body.powerBIReportConfiguration.reportLevelFilters
    }
}

# Create a folder for the reports by date
$folder = (Join-Path $PSScriptRoot "output" (Get-Date -Format "yyyy-MM-dd"))
if( -not (Test-Path $folder) )
{
    New-Item -ItemType Directory -Path $folder
}

$i=0
$tx=0
# Get the contents of the report and replace the parameters
$baseHtml = Get-Content (Join-Path $PSScriptRoot "paginated.html")
foreach($report in $reports)
{
    for($y=0;$y -le $report.instances;$y++)
    {
        #$x = Get-Random -Max $tokens.Count
        $token = $tokens[$tx]
        $html = $baseHtml -replace "##TOKEN##",$token.token
        $html = $html -replace "##EMBEDURL##",$report.embedUrl
        $html = $html -replace "##USERNAME##",$token.userName
        $html = $html -replace "##FILTERS##",($report.parameters|ConvertTo-Json -Depth 8)
        $html | Set-Content (Join-Path $folder "$($i.ToString("00")).html") -Force
        $tx = ($tx -eq $tokens.Count-1) ? 0 : $tx+1
        $i++
    }
}

$i=1
foreach($file in (Get-ChildItem $folder -Filter "*.html"))
{
    # Seeing this a lot 
    # Header: There was an error when attempting to create a new session
    # Error 1: You have exceeded the amount of requests allowed in the current time frame and further requests will fail
    # Error 2: The concurrent paginated operation count for your capacity has reached the maximum limit. Please reduce the number of concurrent paginated renders, subscriptions, and export api requests within your capacity and try again later, or contact your admin
    Write-Host $file.FullName
    Start-Process chrome "--new-window $($file.FullName)"
    if( $i % 10 -eq 0 )
    {
        Read-Host "Press any key to continue"
    }
    $i++
}
