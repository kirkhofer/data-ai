<#
    .SYNOPSIS
    Runs a bunch of tests against a Azure SQL DB trying to kill connections and test pooling affect

    .LINK 
    https://techcommunity.microsoft.com/t5/azure-database-support-blog/reaching-azure-sql-db-connection-limits-in-many-ways/ba-p/1369218
    https://learn.microsoft.com/en-us/azure/azure-sql/database/resource-limits-vcore-single-databases?view=azuresql
    https://learn.microsoft.com/en-us/azure/azure-sql/database/resource-limits-dtu-single-databases?view=azuresql


    Install-Module -Name Az -AllowClobber -Scope AllUsers
    . '/home/kirk/code/playbook/posh/sql-tester.ps1' -MaxPoolSize 10 -RunLimit 20 -MaxThreads 1 -CloseConnection $false
    . '/home/kirk/code/playbook/posh/sql-tester.ps1' -MaxPoolSize 10 -RunLimit 100 -MaxThreads 20 -CloseConnection $true
    . '/home/kirk/code/playbook/posh/sql-tester.ps1' -MaxPoolSize 0 -RunLimit 100 -MaxThreads 20 -CloseConnection $true
    . '/home/kirk/code/playbook/posh/sql-tester.ps1' -MaxPoolSize 0 -RunLimit 100 -MaxThreads 20 -CloseConnection $false

    .EXAMPLE This will error out because of connections in the pool aren't there
    PS> . '/home/kirk/code/playbook/posh/sql-tester.ps1' -RunLimit 100 -ConnectionTimeout 2 -CloseConnection $false
#>
#requires -Modules Az.Accounts
[CmdletBinding()]
param(
    [string]$serverInstance="sql-dai-dev-use.database.windows.net",
    [string]$Database="SampleDB",
    [int]$RunLimit=100,
    [int]$MaxThreads=20,
    [double]$SleepSeconds=.5,
    [int]$MaxPoolSize=0,
    [int]$MinPoolSize=0,
    [int]$ConnectionTimeout=10,
    [bool]$CloseConnection=$true,
    [string]$AppPrefix="sql-tester-",
    [switch]$ShowDetail
)
$ErrorActionPreference = "Stop"

if( $null -eq (Get-AzContext) -or (-not $accessToken) -or ([DateTime]::UtcNow -gt $accessToken.ExpiresOn.UtcDateTime) ) 
{ 
    Connect-AzAccount
    $accessToken = (Get-AzAccessToken -ResourceUrl https://database.windows.net)
    $token = $accessToken.Token
}


$appName = "$AppPrefix$(($CloseConnection) ? 'close' : 'open')-$([datetime]::UtcNow.ToString("yyyyMMddHHmmssfff"))"
#$appName = "$AppPrefix$(($CloseConnection) ? 'close' : 'open')"
$connectionString = "Server=tcp:$ServerInstance,1433;Initial Catalog=$Database;Connection Timeout=$ConnectionTimeout;Application Name=$appName;" 
if ( $MaxPoolSize -gt 0 )
{
    $connectionString += "Max Pool Size=$MaxPoolSize;"
}
if( $MaxPoolSize -gt $MinPoolSize -or ($MaxPoolSize -eq 0 -and $MinPoolSize -gt 0) )
{
    $connectionString += "Min Pool Size=$MinPoolSize;"
}

$items=@()
1..$RunLimit|ForEach-Object {

    $items+=@{
        id = $_
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

    $conn = New-Object System.Data.SqlClient.SQLConnection 
    $conn.ConnectionString = $using:connectionString
    $conn.AccessToken = $using:token
    try
    {
        $conn.Open()
        $process.Status = "Complete"
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = "WAITFOR DELAY '00:00:01';SELECT FORMAT(SYSDATETIME(), 'yyyy-MM-dd HH:mm:ss.fff') AS dt;"
        $process.Results = $cmd.ExecuteScalar()
    }
    catch
    {
        # Write-Output "Error connecting to $ServerInstance on $i"
        # Write-Output $_.Exception.Message
        $process.Status = "Error"
        $process.Results= $_.Exception.Message
    }
    finally 
    {
        # $cmd.Close();
        $cmd.Dispose(); 
        if($using:CloseConnection)
        {
            $conn.Close(); 
        }
    }
    $ts = New-TimeSpan -Start $startTime -End ([DateTime]::UtcNow)    
    $process.TotalSeconds = $ts.TotalSeconds
}

while($job.State -eq 'Running')
{
    # $sync.Keys | Foreach-Object {
    #     # If key is not defined, ignore
    #     if(![string]::IsNullOrEmpty($sync.$_.keys))
    #     {
    #         if( -not $sync.$_.Completed )
    #         {
    #             Write-Host "Id: $($sync.$_.Id)"
    #         }
    #     }
    # }
    $run = ($sync.Keys | ?{$sync.$_.Status -eq "Running"}).length
    $cnt = ($sync.Keys | ?{$sync.$_.Status -and $sync.$_.Status -ne "Running"}).length
    
    
    $sql = "
    SELECT COUNT(*) AS session_count
    FROM sys.dm_exec_sessions
    WHERE program_name = '$appName';
    "
    $resultSql=Invoke-SqlCmd -ServerInstance $serverInstance -database $Database -query $sql -AccessToken $token

    $sessionCount = 0
    if( $resultSql )
    {
        $sessionCount=[int]$resultSql.session_count
    }
    # Write-Host "Session Count: $($resultSql.session_count) LastRequest_Minutes: $($resultSql.LastRequest_Minutes)"
    Write-Host "$([datetime]::utcnow.ToString("HH:mm:ss.fff")): Running...$($run) Completed...$($cnt) Sessions...$sessionCount"
    # Write-Host "$([datetime]::utcnow.ToString("HH:mm:ss.fff")): Running...$($run) Completed...$($cnt)"
    
    # Wait to refresh to not overload gui
    Start-Sleep -Seconds $SleepSeconds
}    
if( $ShowDetail )
{
    $sync.Keys | Foreach-Object {
        # $c=$items|Where-Object id -eq $sync.$_.Id
        Write-Host "Id: $($sync.$_.Id) StartTime: $($sync.$_.StartTime.ToString("HH:mm:ss.fff")) TotalSeconds: $($sync.$_.TotalSeconds) Status: $($sync.$_.Status) Results: $($sync.$_.Results)"
    }
}
($sync.Keys | %{$c=$items|Where-Object id -eq $sync.$_.Id;"{0}" -f $sync.$_.Status}) | Group-Object

Write-Host $connectionString

$sql = "
SELECT program_name,
    status,
    COUNT(session_id) AS session_count
    ,MAX(DATEDIFF(minute,last_request_end_time,GETDATE())) AS MaxRequest_Minutes
    ,MIN(DATEDIFF(minute,last_request_end_time,GETDATE())) AS MinRequest_Minutes
FROM sys.dm_exec_sessions
WHERE program_name = '$appName'
GROUP BY program_name,status;
"
$resultSql=Invoke-SqlCmd -ServerInstance $serverInstance -database $Database -query $sql -AccessToken $token
if( $resultSql )
{
    Write-Host "Session Count: $($resultSql.session_count) MaxRequest_Minutes: $($resultSql.MaxRequest_Minutes) MinRequest_Minutes: $($resultSql.MinRequest_Minutes)"
}
else
{
    Write-Host "No Sessions found for $appName"
}

# Clear all the pools
[System.Data.SqlClient.SQLConnection]::ClearAllPools()