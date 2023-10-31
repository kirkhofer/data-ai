<#
.SYNOPSIS
Runs a bunch of tests against Azure OpenAI API endpoints

.DESCRIPTION

Reference: https://learn.microsoft.com/en-us/powershell/scripting/learn/deep-dives/write-progress-across-multiple-threads?view=powershell-7.3
Found this out: Workflow not supported in PowerShell 6.0+

.EXAMPLE
PS> . '/load-tester.ps1' -MaxThreads 10 -MaxItems 10

16:56:43.250: Running...0 Completed...0
16:56:46.331: Running...4 Completed...2
16:56:47.851: Running...5 Completed...4
16:56:48.353: Running...5 Completed...4
16:56:49.367: Running...3 Completed...7
16:56:49.868: Running...3 Completed...7
16:56:50.370: Running...2 Completed...8
Id: 2 StartTime: 16:56:43.263 TotalSeconds: 4.4207237 StatusCode: 200 configId: 0
Id: 1 StartTime: 16:56:43.262 TotalSeconds: 3.0659088 StatusCode: 200 configId: 1

Count Name                      Group
----- ----                      -----
    5 0-200                     {0-200, 0-200, 0-200, 0-200…}
    5 1-200                     {1-200, 1-200, 1-200, 1-200…}
#>
[CmdLetBinding()]
param(
    # The deployment id to use from Azure OpenAI
    [string]$DeploymentId="gpt-35-turbo",
    # The maximum number of threads to use from your client...linux or windows
    [int]$MaxThreads=5,
    # How many items to throw at the process
    [int]$MaxItems=10,
    # How long to wait between UI refreshes. Does not impact performance
    [double]$SleepSeconds=.5
)
$ErrorActionPreference="Stop"

if( $PSScriptRoot -eq "")
{
  $file = Get-Content "aoai/json.env"
}
else
{
  $file = Get-Content (Join-Path $PSScriptRoot "json.env")
}

$json = ($file|ConvertFrom-Json)

$items=@()
1..$MaxItems|ForEach-Object {
    $items+=@{
        id = $_
        configId = Get-Random -Minimum 0 -Maximum $json.Count
        message = "Count to $(Get-Random -Minimum 50 -Maximum 101), with a comma between each number and no newlines. E.g., 1, 2, 3, ..."
    }
}

# Create a hashtable for process.
# Keys should be ID's of the processes
$origin = @{}
$items | Foreach-Object {$origin.($_.id) = @{}}
$sync = [System.Collections.Hashtable]::Synchronized($origin)

$job = $items | Foreach-Object -ThrottleLimit $MaxThreads -AsJob -Parallel {

    $syncCopy = $using:sync
    $process = $syncCopy.$($PSItem.Id)

    $startTime = ([DateTime]::UtcNow)

    $process.Id = $PSItem.id
    $process.Status = "Running"
    $process.StartTime=$startTime

    $config = $using:json    

    $uri = "{0}openai/deployments/{1}/chat/completions?api-version=2023-05-15" -f $config[$PSItem.configId].endpoint,$using:DeploymentId
    $headers = @{
        "Content-Type" = "application/json"
        "api-key" = $config[$PSItem.configId].key
    }

    $body=@{}
    $messages=@()
    $messages+=@{
        role = "user"
        content = $PSItem.message
    }

    $body.Add("messages",$Messages)
    $body.Add("temperature",0)
    $body.Add("max_tokens",500)
    
    $body = $body | ConvertTo-Json
    $body = [System.Text.Encoding]::UTF8.GetBytes($body)

    try
    {
        $resp = Invoke-WebRequest -Uri $uri -Method Post -Headers $headers -Body $body -SkipHttpErrorCheck
        $process.StatusCode = $resp.StatusCode
        $process.Results = $resp.Content
        $process.Status = "Complete"
    }
    catch
    {
        $process.Results= $_.Exception.Message
        $process.StatusCode = $_.Exception.Response.StatusCode.value__
        $process.Status = "Error"
    }
    

    $ts = New-TimeSpan -Start $startTime -End ([DateTime]::UtcNow)    
    $process.TotalSeconds = $ts.TotalSeconds
}

while($job.State -eq 'Running')
{
    $run = ($sync.Keys | ?{$sync.$_.Status -eq "Running"}).length
    $cnt = ($sync.Keys | ?{$sync.$_.Status -and $sync.$_.Status -ne "Running"}).length
    Write-Host "$([datetime]::utcnow.ToString("HH:mm:ss.fff")): Running...$($run) Completed...$($cnt)"

    # Wait to refresh to not overload gui
    Start-Sleep -Seconds $SleepSeconds
}

$sync.Keys | Foreach-Object {
    $c=$items|Where-Object id -eq $sync.$_.Id
    Write-Host "Id: $($sync.$_.Id) StartTime: $($sync.$_.StartTime.ToString("HH:mm:ss.fff")) TotalSeconds: $($sync.$_.TotalSeconds) StatusCode: $($sync.$_.StatusCode) configId: $($c.configId)"
}

# Summary of what happened
($sync.Keys | %{$c=$items|Where-Object id -eq $sync.$_.Id;"{1}-{0}" -f $sync.$_.StatusCode,$c.configId}) | Group-Object
