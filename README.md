# data-ai
Repo to share things I have learned over my many years of programming and data experiences

## My install
- Have a PC and a Mac (MacBook Pro mid-2012...please send me a new one)
- VS Code
- PowerShell Core (Not Windows PowerShell)
- Windows: Running on WSL (Windows Subsystem for Linux)

# Power BI
I have used Power BI since it came out and also used Crystal Reports and SQL Server Reporting Services for a long time. Sharing some knowledge here to help others.
# Power BI Export Tester
Have need to bulk test how a capacity would be impacted by a bunch of requests running against Power BI Reports or Paginated Reports. Use the Tester and JSON config to run against your tenant. 

> NOTE: You need a Power BI Capacity (Either Premium (P SKU) or Embedded (A SKU))
1. Clone or fork this repo
    - `git clone https://github.com/kirkhofer/data-ai.git`
1. Edit the `powerbi/pbi-export-tester.json` to setup your own configuration
    - My example has some simple reports and parameters to test
    - NOTE: I plan to add the code for SQL and the report files (RDL and PBIX) soon
1. Run the `pbi-export-tester.ps1`
    - This will install the Power BI modules if you don't already have them

# Azure Data Explorer
Have a complete [walkthrough](data-explorer/free-cluster-demo.md) using a Free Cluster (No cost) to test ADX
