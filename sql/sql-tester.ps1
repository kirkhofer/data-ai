<#
    .SYNOPSIS
    Runs a bunch of tests against a Azure SQL DB trying to kill connections and test pooling affect

    .LINK 
    https://techcommunity.microsoft.com/t5/azure-database-support-blog/reaching-azure-sql-db-connection-limits-in-many-ways/ba-p/1369218
    https://learn.microsoft.com/en-us/azure/azure-sql/database/resource-limits-vcore-single-databases?view=azuresql
    https://learn.microsoft.com/en-us/azure/azure-sql/database/resource-limits-dtu-single-databases?view=azuresql


    Install-Module -Name Az -AllowClobber -Scope AllUsers
    . '/home/kirk/code/playbook/posh/sql-tester.ps1' -MaxPoolSize 10 -RunLimit 20 -RunType "Sequential" -CloseConnection $false
    . '/home/kirk/code/playbook/posh/sql-tester.ps1' -MaxPoolSize 10 -RunLimit 100 -RunType "Parallel" -CloseConnection $true
    . '/home/kirk/code/playbook/posh/sql-tester.ps1' -MaxPoolSize 0 -RunLimit 100 -RunType "Parallel" -CloseConnection $true
    . '/home/kirk/code/playbook/posh/sql-tester.ps1' -MaxPoolSize 0 -RunLimit 100 -RunType "Parallel" -CloseConnection $false

    .EXAMPLE This will error out because of connections in the pool aren't there
    PS> . '/home/kirk/code/playbook/posh/sql-tester.ps1' -RunLimit 100 -ConnectionTimeout 2 -CloseConnection $false
#>
#requires -Modules Az.Accounts
[CmdletBinding()]
param(
    [string]$ServerInstance="sql-dai-dev-use.database.windows.net",
    [string]$Database="SampleDB",
    [int]$RunLimit=10,
    [ValidateSet("Sequential", "Parallel")]
    [string]$RunType="Parallel",
    [int]$MaxThreads=20,
    [double]$SleepSeconds=.5,
    [int]$MaxPoolSize=0,
    [int]$ConnectionTimeout=5,
    [bool]$CloseConnection=$true
)
$ErrorActionPreference = "Stop"

if( $null -eq (Get-AzContext) -or (-not $accessToken) -or ([DateTime]::UtcNow -gt $accessToken.ExpiresOn.UtcDateTime) ) 
{ 
    Connect-AzAccount
    $accessToken = (Get-AzAccessToken -ResourceUrl https://database.windows.net)
    $token = $accessToken.Token
}

$connectionString = "Server=tcp:$ServerInstance,1433;Initial Catalog=$Database;Connection Timeout=$ConnectionTimeout" 
if ( $MaxPoolSize -gt 0 )
{
    $connectionString += ";Max Pool Size=$MaxPoolSize;"
}
if( $RunType -eq "Sequential" )
{
    $i=0
    while($i -lt $RunLimit)
    {
        $conn = New-Object System.Data.SqlClient.SQLConnection 
        $conn.ConnectionString = $connectionString
        $conn.AccessToken = $token
        try
        {
            $conn.Open()
            $cmd = $conn.CreateCommand()
            $cmd.CommandText = "SELECT GETDATE() AS dt"
            $dt = [datetime]$cmd.ExecuteScalar()
            Write-Output "Run: $i Time: $dt"
        }
        catch
        {
            Write-Output "Run: $i Error: $($_.Exception.Message)"
        }
        finally 
        {
            $cmd.Dispose(); 
            if($CloseConnection)
            {
                $conn.Close(); 
            }
        }

        $i++
    }
}
elseif( $RunType -eq "Parallel" )
{
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
            $cmd.CommandText = "SELECT GETDATE() AS dt"
            $process.Results = [datetime]$cmd.ExecuteScalar()
        }
        catch
        {
            $process.Status = "Error"
            $process.Results= $_.Exception.Message
        }
        finally 
        {
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
        $run = ($sync.Keys | ?{$sync.$_.Status -eq "Running"}).length
        $cnt = ($sync.Keys | ?{$sync.$_.Status -and $sync.$_.Status -ne "Running"}).length
        Write-Host "$([datetime]::utcnow.ToString("HH:mm:ss.fff")): Running...$($run) Completed...$($cnt)"
        # Wait to refresh to not overload gui
        Start-Sleep -Seconds $SleepSeconds
    }    
    $sync.Keys | Foreach-Object {
        Write-Host "Id: $($sync.$_.Id) StartTime: $($sync.$_.StartTime.ToString("HH:mm:ss.fff")) TotalSeconds: $($sync.$_.TotalSeconds) Status: $($sync.$_.Status) Results: $($sync.$_.Results)"
    }

    ($sync.Keys | %{$c=$items|Where-Object id -eq $sync.$_.Id;"{0}" -f $sync.$_.Status}) | Group-Object
}
Write-Host $connectionString
