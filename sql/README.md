# SQL Tester
Use this [code](sql-tester.ps1) to execute and see how a connection pool works or doesn't. See what happens when you don't close/dispose of a connection

1. Make sure to update the `$serverInstance` and the `$Database`
1. Play around with other settings for Parallel vs Sequential runs as well
    ```powershell
    # Run the tester WITHOUT closing and see the errors on the pools
    ./sql-tester.ps1 -RunLimit 100 -CloseConnection $false -ConnectionTimeout 2

    # Run the tester closing and see no errors
    ./sql-tester.ps1 -RunLimit 100 -CloseConnection $true -ConnectionTimeout 2
    ```
1. Test in SQL to see what happens with session counts
    ```sql
    SELECT login_name,
        status,
        COUNT(session_id) AS session_count
    FROM sys.dm_exec_sessions
    WHERE session_id <> @@SPID
    GROUP BY login_name,status;
    ```